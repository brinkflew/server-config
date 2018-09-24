# Debian Partitioning

Following is a recommended partitioning setup for Debian Stretch systems with a
50 GB disk size.

| Partition        | Bind To | Options                   | Size     |
| ---------------- | ------- | :-----------------------: | -------: |
| `/`              |         |                           | 15 GB    |
| `/boot`          |         |                           | 250 MB   |
| `/tmp`           |         | `nodev` `nosuid` `noexec` | 2 GB     |
| `/var`           |         |                           | 5 GB     |
| `/var/tmp`       | `/tmp`  |                           |          |
| `/var/log`       |         |                           | 10 GB    |
| `/var/log/audit` |         |                           | 3 GB     |
| `/home`          |         | `nodev`                   | 15 GB    |
| `/run/shm`       |         | `nodev` `nosuid` `noexec` |          |
| Removable media  |         | `nodev` `nosuid` `noexec` |          |


/boot             p   +250M     sdb1
/tmp              p   +2G       sdb2
NA                e             sdb3
/home             l   +15G      sdb5
/var              l   +5G       sdb6
/var/log          l   +10G      sdb7
/var/log/audit    l   +2G       sdb8
/                 l   +10G      sdb9
/                 l   +10G      sdb10
