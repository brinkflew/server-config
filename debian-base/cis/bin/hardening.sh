#!/bin/bash

#
# CIS Debian 7/8 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# Main script : Execute hardening considering configuration
#

LONG_SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
DISABLED_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
TOTAL_CHECKS=0
TOTAL_TREATED_CHECKS=0
AUDIT=0
APPLY=0
AUDIT_ALL=0
AUDIT_ALL_ENABLE_PASSED=0
ALLOW_SERVICE_LIST=0
SET_HARDENING_LEVEL=0
SUDO_MODE=''

usage() {
    cat << EOF
$LONG_SCRIPT_NAME <RUN_MODE> [OPTIONS], where RUN_MODE is one of:

    --help -h
        Show this help

    --apply
        Apply hardening for enabled scripts.
        Beware that NO confirmation is asked whatsoever, which is why you're warmly
        advised to use --audit before, which can be regarded as a dry-run mode.

    --audit
        Audit configuration for enabled scripts.
        No modification will be made on the system, we'll only report on your system
        compliance for each script.

    --audit-all
        Same as --audit, but for *all* scripts, even disabled ones.
        This is a good way to peek at your compliance level if all scripts were enabled,
        and might be a good starting point.

    --audit-all-enable-passed
        Same as --audit-all, but in addition, will *modify* the individual scripts
        configurations to enable those which passed for your system.
        This is an easy way to enable scripts for which you're already compliant.
        However, please always review each activated script afterwards, this option
        should only be regarded as a way to kickstart a configuration from scratch.
        Don't run this if you have already customized the scripts enable/disable
        configurations, obviously.

    --set-hardening-level <level>
        Modifies the configuration to enable/disable tests given an hardening level,
        between 1 to 5. Don't run this if you have already customized the scripts
        enable/disable configurations.
        1: very basic policy, failure to pass tests at this level indicates severe
            misconfiguration of the machine that can have a huge security impact
        2: basic policy, some good practice rules that, once applied, shouldn't
            break anything on most systems
        3: best practices policy, passing all tests might need some configuration
            modifications (such as specific partitioning, etc.)
        4: high security policy, passing all tests might be time-consuming and
            require high adaptation of your workflow
        5: placebo, policy rules that might be very difficult to apply and maintain,
            with questionable security benefits

    --allow-service <service>
        Use with --set-hardening-level.
        Modifies the policy to allow a certain kind of services on the machine, such
        as http, mail, etc. Can be specified multiple times to allow multiple services.
        Use --allow-service-list to get a list of supported services.

OPTIONS:

    --only <test_number>
        Modifies the RUN_MODE to only work on the test_number script.
        Can be specified multiple times to work only on several scripts.
        The test number is the numbered prefix of the script,
        i.e. the test number of 1.2_script_name.sh is 1.2.

    --sudo
        This option lets you audit your system as a normal user, but allows sudo
        escalation to gain read-only access to root files. Note that you need to
        provide a sudoers file with NOPASSWD option in /etc/sudoers.d/ because
        the '-n' option instructs sudo not to prompt for a password.
        Finally note that '--sudo' mode only works for audit mode.

EOF
    exit 0
}

if [ $# = 0 ]; then
    usage
fi

declare -a TEST_LIST ALLOWED_SERVICES_LIST

# Arguments parsing
while [[ $# > 0 ]]; do
    ARG="$1"
    case $ARG in
        --audit)
            AUDIT=1
        ;;
        --audit-all)
            AUDIT_ALL=1
        ;;
        --audit-all-enable-passed)
            AUDIT_ALL_ENABLE_PASSED=1
        ;;
        --apply)
            APPLY=1
        ;;
        --allow-service-list)
            ALLOW_SERVICE_LIST=1
        ;;
        --allow-service)
            ALLOWED_SERVICES_LIST[${#ALLOWED_SERVICES_LIST[@]}]="$2"
            shift
        ;;
        --set-hardening-level)
            SET_HARDENING_LEVEL="$2"
            shift
        ;;
        --only)
            TEST_LIST[${#TEST_LIST[@]}]="$2"
            shift
        ;;
        --sudo)
            SUDO_MODE='--sudo'
        ;;
        -h|--help)
            usage
        ;;
        *)
            usage
        ;;
    esac
    shift
done

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

[ -r $CIS_ROOT_DIR/lib/constants.sh  ] && . $CIS_ROOT_DIR/lib/constants.sh
[ -r $CIS_ROOT_DIR/etc/hardening.cfg ] && . $CIS_ROOT_DIR/etc/hardening.cfg
[ -r $CIS_ROOT_DIR/lib/common.sh     ] && . $CIS_ROOT_DIR/lib/common.sh
[ -r $CIS_ROOT_DIR/lib/utils.sh      ] && . $CIS_ROOT_DIR/lib/utils.sh

# If --allow-service-list is specified, don't run anything, just list the supported services
if [ "$ALLOW_SERVICE_LIST" = 1 ] ; then
    declare -a HARDENING_EXCEPTIONS_LIST
    for SCRIPT in $(ls $CIS_ROOT_DIR/bin/hardening/*.sh -v); do
        template=$(grep "^HARDENING_EXCEPTION=" "$SCRIPT" | cut -d= -f2)
        [ -n "$template" ] && HARDENING_EXCEPTIONS_LIST[${#HARDENING_EXCEPTIONS_LIST[@]}]="$template"
    done
    echo "Supported services are: "$(echo "${HARDENING_EXCEPTIONS_LIST[@]}" | tr " " "\n" | sort -u | tr "\n" " ")
    exit 0
fi

# If --set-hardening-level is specified, don't run anything, just apply config for each script
if [ -n "$SET_HARDENING_LEVEL" -a "$SET_HARDENING_LEVEL" != 0 ] ; then
    if ! grep -q "^[12345]$" <<< "$SET_HARDENING_LEVEL" ; then
        echo "Bad --set-hardening-level specified ('$SET_HARDENING_LEVEL'), expected 1 to 5"
        exit 1
    fi

    for SCRIPT in $(ls $CIS_ROOT_DIR/bin/hardening/*.sh -v); do
        SCRIPT_BASENAME=$(basename $SCRIPT .sh)
        script_level=$(grep "^HARDENING_LEVEL=" "$SCRIPT" | cut -d= -f2)
        if [ -z "$script_level" ] ; then
            echo "The script $SCRIPT_BASENAME doesn't have a hardening level, configuration untouched for it"
            continue
        fi
        wantedstatus=disabled
        [ "$script_level" -le "$SET_HARDENING_LEVEL" ] && wantedstatus=enabled
        sed -i -re "s/^status=.+/status=$wantedstatus/" $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg
    done
    echo "Configuration modified to enable scripts for hardening level at or below $SET_HARDENING_LEVEL"
    exit 0
fi

# Parse every scripts and execute them in the required mode
for SCRIPT in $(ls $CIS_ROOT_DIR/bin/hardening/*.sh -v); do
    if [ ${#TEST_LIST[@]} -gt 0 ] ; then
        # --only X has been specified at least once, is this script in my list ?
        SCRIPT_PREFIX=$(grep -Eo '^[0-9.]+' <<< "$(basename $SCRIPT)")
        SCRIPT_PREFIX_RE=$(sed -e 's/\./\\./g' <<< "$SCRIPT_PREFIX")
        if ! grep -qEw "$SCRIPT_PREFIX_RE" <<< "${TEST_LIST[@]}"; then
            # not in the list
            continue
        fi
    fi

    info "Treating $SCRIPT"
    
    if [ $AUDIT = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit $SUDO_MODE"
        $SCRIPT --audit $SUDO_MODE
    elif [ $AUDIT_ALL = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit-all $SUDO_MODE"
        $SCRIPT --audit-all $SUDO_MODE
    elif [ $AUDIT_ALL_ENABLE_PASSED = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit-all $SUDO_MODE"
        $SCRIPT --audit-all $SUDO_MODE
    elif [ $APPLY = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT"
        $SCRIPT
    fi

    SCRIPT_EXITCODE=$?

    debug "Script $SCRIPT finished with exit code $SCRIPT_EXITCODE"
    case $SCRIPT_EXITCODE in
        0)
            debug "$SCRIPT passed"
            PASSED_CHECKS=$((PASSED_CHECKS+1))
            if [ $AUDIT_ALL_ENABLE_PASSED = 1 ] ; then
                SCRIPT_BASENAME=$(basename $SCRIPT .sh)
                sed -i -re 's/^status=.+/status=enabled/' $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg
                info "Status set to enabled in $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg"
            fi
        ;;    
        1)
            debug "$SCRIPT failed"
            FAILED_CHECKS=$((FAILED_CHECKS+1))
        ;;
        2)
            debug "$SCRIPT is disabled"
            DISABLED_CHECKS=$((DISABLED_CHECKS+1))
        ;;
    esac

    TOTAL_CHECKS=$((TOTAL_CHECKS+1))
 
done

TOTAL_TREATED_CHECKS=$((TOTAL_CHECKS-DISABLED_CHECKS))

printf "%40s\n" "################### SUMMARY ###################"
printf "%30s %s\n"        "Total Available Checks :" "$TOTAL_CHECKS"
printf "%30s %s\n"        "Total Runned Checks :" "$TOTAL_TREATED_CHECKS"
printf "%30s [ %7s ]\n"   "Total Passed Checks :" "$PASSED_CHECKS/$TOTAL_TREATED_CHECKS"
printf "%30s [ %7s ]\n"   "Total Failed Checks :" "$FAILED_CHECKS/$TOTAL_TREATED_CHECKS"
printf "%30s %.2f %%\n"   "Enabled Checks Percentage :" "$( echo "($TOTAL_TREATED_CHECKS/$TOTAL_CHECKS) * 100" | bc -l)"
if [ $TOTAL_TREATED_CHECKS != 0 ]; then
    printf "%30s %.2f %%\n"   "Conformity Percentage :" "$( echo "($PASSED_CHECKS/$TOTAL_TREATED_CHECKS) * 100" | bc -l)"
else
    printf "%30s %s %%\n"   "Conformity Percentage :" "N.A" # No check runned, avoid division by 0 
fi