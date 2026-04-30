# 01 - VM Creation

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Create the VM itself in OCI, with the exact shape and naming used in the working deployment.

## OCI click path

1. Log into Oracle Cloud Infrastructure
2. Open the region selector
3. Use the same region consistently for everything
4. Go to:
   - `Compute`
   - `Instances`
   - `Create instance`

## Instance values

Use these values:

- Name: `<vm-name>`
- Placement: default availability domain in your target region
- Image:
  - Ubuntu image
  - use the default recent Ubuntu Oracle image unless you have a strong reason not to

## Shape values

Target shape:

- `VM.Standard.A1.Flex`
- `2 OCPU`
- `12 GB memory`

Boot volume:

- `50 GB`

## If A1 capacity is unavailable

This was the real workaround used:

1. create the instance as:
   - `VM.Standard.A2.Flex`
2. let it create successfully
3. stop the instance
4. edit the shape
5. change to:
   - `VM.Standard.A1.Flex`
6. start it again

That path depended on trial-credit capacity and was the practical escape hatch when direct A1 creation was blocked.

## SSH key

In the instance creation flow, use:

- `Paste public keys`

Paste the contents of your public key, for example:

```text
~/.ssh/id_ed25519.pub
```

Important:

- paste the `.pub` key there
- not the private key

## Networking selection during creation

If you already created the VCN and subnet, attach:

- VCN: `<vcn-name>`
- subnet: `<public-subnet-name>`

If not, pause here and do:

- [02-networking.md](02-networking.md)

## After creation

Verify on the instance page:

- lifecycle state: `Running`
- public IP exists
- shape is what you expect

If you used the A2 workaround, verify again after the reshape:

- instance shape is now `VM.Standard.A1.Flex`

## CLI checks

From Oracle Cloud Shell:

```bash
oci compute instance get \
  --instance-id <INSTANCE_OCID> \
  --query 'data.shape'
```

Expected result:

```text
"VM.Standard.A1.Flex"
```
