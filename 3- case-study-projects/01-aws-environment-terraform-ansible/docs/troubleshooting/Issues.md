i got an terraform dependency issue when updating existing security groups
the issue because i was have exisitng security groups depends on another security group
so terrafrom cannot delete security group because it associated with another security groups as an inbound interface rule

solution: first i replaced the associated security group with the new one using the below commands:-
```bash
terraform apply \
  -target=aws_security_group.mariadb_security_group \
  -target=aws_security_group.rabbitmq_security_group \
  -target=aws_security_group.memcached_security_group
```
then i deleted the unused security group using the below

```bash
terraform apply
```