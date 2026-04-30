# 02 - Networking

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Create the public networking path correctly the first time:

- VCN
- public subnet
- internet gateway
- route rule
- security list ingress

## VCN creation

OCI path:

- `Networking`
- `Virtual cloud networks`
- `Start VCN Wizard`
  or create manually if you prefer

Use:

- VCN name: `<vcn-name>`
- VCN CIDR: `10.0.0.0/16`

## Public subnet

Create:

- subnet name: `<public-subnet-name>`
- CIDR: `10.0.0.0/24`
- public subnet enabled

## Internet gateway

OCI path:

- `Networking`
- `Virtual cloud networks`
- `<vcn-name>`
- `Gateways`
- `Create Internet Gateway`

Use:

- name: `<internet-gateway-name>`

Important:

- do **not** attach a route table in the gateway's advanced options
- leave the gateway's route-table association alone

That screen is a trap for this setup.

## Route table rule

OCI path:

- `Networking`
- `Virtual cloud networks`
- `<vcn-name>`
- `Routing`
- open the VCN's default route table
- `Route Rules`
- `Add Route Rules`

Add:

- Target Type: `Internet Gateway`
- Destination CIDR Block: `0.0.0.0/0`
- Target Internet Gateway: `<internet-gateway-name>`

Do **not** try to do this from the gateway association screen.

## Security list ingress rules

OCI path:

- `Networking`
- `Virtual cloud networks`
- `<vcn-name>`
- `Subnets`
- open `<public-subnet-name>`
- note the attached security list
- open that exact security list
- `Add Ingress Rules`

Add these rules:

### SSH

- Source Type: `CIDR`
- Source CIDR: `0.0.0.0/0`
- IP Protocol: `TCP`
- Destination Port Range: `22`
- Stateless: `off`

### HTTP

- Source Type: `CIDR`
- Source CIDR: `0.0.0.0/0`
- IP Protocol: `TCP`
- Destination Port Range: `80`
- Stateless: `off`

### HTTPS

- Source Type: `CIDR`
- Source CIDR: `0.0.0.0/0`
- IP Protocol: `TCP`
- Destination Port Range: `443`
- Stateless: `off`

## Verify attached objects from Cloud Shell

List VNIC attachment:

```bash
oci compute vnic-attachment list \
  --compartment-id <COMPARTMENT_OCID> \
  --instance-id <INSTANCE_OCID>
```

Get VNIC:

```bash
oci network vnic get --vnic-id <VNIC_OCID>
```

Check:

- `public-ip` exists
- `subnet-id` is correct

Get subnet:

```bash
oci network subnet get --subnet-id <SUBNET_OCID>
```

Check:

- `prohibit-public-ip-on-vnic` is `false`
- route table is attached
- security list is attached

Get route table:

```bash
oci network route-table get --rt-id <ROUTE_TABLE_OCID>
```

Expected:

- `0.0.0.0/0` routes to the internet gateway

Get security list:

```bash
oci network security-list get --security-list-id <SECURITY_LIST_OCID>
```

Expected:

- TCP `22`
- TCP `80`
- TCP `443`

## Real Oracle trap from this deployment

If OCI tells you something like:

> Rules in the route table must use private IP as a target

you are almost certainly editing the wrong screen:

- gateway route-table association

instead of:

- subnet route table rules

Back out and edit the route table directly.
