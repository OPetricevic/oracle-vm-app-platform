# 08 - Verification and Debugging

Back to:

- [Oracle VM Runbook](ORACLE_VM_RUNBOOK.md)

## Goal

Debug the deployment path in a fixed order so you stop guessing.

## Verify in layers

### Layer 1: backend local

On the VM:

```bash
curl -i http://127.0.0.1:3600/api/health
curl -i http://127.0.0.1:3601/api/health
```

Expected:

- `200 OK`
- `ok`

### Layer 2: Caddy local

On the VM:

```bash
curl -i http://127.0.0.1/api/health
curl -i http://10.0.0.79/api/health
```

Expected:

- `200 OK`
- `ok`

### Layer 3: public IP direct

From your own machine:

```bash
curl -i http://<public-ip>/api/health
```

Expected:

- `200 OK`
- `ok`

### Layer 4: Cloudflare/public host

From your own machine:

```bash
curl -i https://<frontend-host>/api/health
```

Expected:

- `200 OK`
- `ok`

## If public traffic still times out

### Step 1: prove whether packets reach the VM

On the VM:

```bash
sudo timeout 15 tcpdump -n -l -i any 'tcp port 80'
```

Then from your own machine, hit:

```bash
curl -i http://<public-ip>/api/health
```

Interpretation:

- no packets seen -> Oracle/network problem
- SYN packets seen -> VM-side problem

## If Oracle and UFW look correct but HTTP still fails

Inspect:

```bash
sudo iptables -L INPUT --line-numbers
sudo iptables -L FORWARD --line-numbers
sudo iptables-save
```

In the real deployment, the final blocker was:

- stale old `iptables` `REJECT` rules above the UFW chains

That meant:

- OCI security rules were correct
- UFW rules were correct
- packets reached the VM
- but the VM still never answered public HTTP correctly

## If you fix iptables, persist the fix

Do not stop after fixing the live rules in memory.

Also update the saved rules:

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

Otherwise reboot can reintroduce the old bad state.

## If Cloudflare returns `523`

Treat it as a symptom, not a conclusion.

Check:

1. backend local
2. Caddy local
3. direct public IP
4. then Cloudflare

In this deployment, `523` was not the root problem. The root problem was stale firewall state on the VM.
