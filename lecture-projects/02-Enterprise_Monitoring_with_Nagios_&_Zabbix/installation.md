Follow the steps in the below link

https://www.zabbix.com/download?zabbix=7.4&os_distribution=centos&os_version=9&components=server_frontend_agent&db=pgsql&ws=nginx

![alt text](image-1.png)


before step c initialising the database make sure the appropriate version of database is already installed

```bash
dnf module install postgresql:16/server
postgresql-setup --initdb
systemctl enable --now postgresql
```
