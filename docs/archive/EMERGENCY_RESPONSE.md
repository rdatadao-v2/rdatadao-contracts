# Emergency Response Playbook - RDAT V2

**Last Updated**: August 6, 2025  
**Status**: Complete emergency procedures documentation  
**Criticality**: HIGH - All team members must be familiar with these procedures  

---

## =¨ Overview

This playbook defines emergency response procedures for various security incidents and operational emergencies in the RDAT V2 ecosystem. Response time is critical - all team members should be familiar with these procedures.

---

## =Ê Incident Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| **CRITICAL** | Immediate threat to funds or system | < 15 minutes | Active exploit, private key compromise |
| **HIGH** | Significant risk, not immediate | < 1 hour | Suspicious activity, potential vulnerability |
| **MEDIUM** | Operational issue, low risk | < 4 hours | Failed transactions, UI issues |
| **LOW** | Minor issue, no immediate risk | < 24 hours | Documentation errors, minor bugs |

---

## =4 CRITICAL: Active Exploit Response

### Detection Indicators
- Unexpected token movements
- Abnormal gas consumption
- Multiple failed transactions
- Community reports of losses

### Immediate Actions (0-15 minutes)

1. **PAUSE ALL CONTRACTS** (Any Emergency Team member)
   ```bash
   # Execute emergency pause
   cast send $EMERGENCY_PAUSE "pauseAll()" \
     --private-key $EMERGENCY_KEY \
     --rpc-url $RPC_URL
   ```

2. **Alert Core Team**
   - Telegram: [Emergency Channel]
   - Discord: @emergency-response
   - Email: security@rdatadao.com

3. **Document Initial Findings**
   - Transaction hashes
   - Affected addresses
   - Estimated impact

### Investigation Phase (15-60 minutes)

1. **Gather Evidence**
   - Export all relevant transactions
   - Screenshot suspicious activity
   - Check all contract states

2. **Identify Attack Vector**
   - Review recent transactions
   - Check for known vulnerabilities
   - Analyze attack pattern

3. **Assess Damage**
   - Total funds at risk
   - Number of affected users
   - Contracts compromised

### Mitigation Phase (1-4 hours)

1. **Deploy Fixes**
   - Develop patch (if applicable)
   - Test on fork
   - Prepare deployment

2. **Communication**
   - Draft incident report
   - Prepare user notifications
   - Update status page

3. **Execute Recovery**
   - Deploy fixes via multisig
   - Unpause when safe
   - Monitor for issues

---

## =á HIGH: Suspicious Activity Response

### Examples
- Unusual staking patterns
- Potential governance attacks
- Abnormal reward claims

### Response Steps

1. **Monitor & Document** (0-30 minutes)
   - Track suspicious addresses
   - Document transaction patterns
   - Calculate potential impact

2. **Escalate if Needed** (30-60 minutes)
   - Consult security team
   - Consider preventive pause
   - Prepare mitigation plan

3. **Take Action** (1-4 hours)
   - Implement restrictions
   - Update parameters
   - Notify affected users

---

## = Key Compromise Procedures

### If Private Key Compromised

1. **Immediate Actions**
   - Revoke all permissions from compromised address
   - Transfer any accessible funds to secure address
   - Pause affected contracts

2. **Multisig Response**
   ```solidity
   // Remove compromised signer
   multisig.removeOwner(compromisedAddress);
   
   // Add new secure signer
   multisig.addOwner(newSecureAddress);
   ```

3. **Audit Trail**
   - Document compromise details
   - Review access logs
   - Update security procedures

---

## < Cross-Chain Bridge Issues

### Bridge Halted

1. **Verify on Both Chains**
   - Check Base status
   - Check Vana status
   - Verify validator status

2. **Coordinate Validators**
   - Contact all 3 validators
   - Verify consensus
   - Plan restart

3. **Resume Operations**
   - Clear pending migrations
   - Update validator set if needed
   - Monitor for issues

### Invalid Migration Detected

1. **Challenge Period** (0-6 hours)
   - Submit challenge transaction
   - Provide evidence
   - Alert validators

2. **Resolution**
   - Validators review evidence
   - Vote on validity
   - Execute decision

---

## =Þ Emergency Contacts

### Core Team (To be filled at deployment)
| Role | Name | Contact | Timezone |
|------|------|---------|----------|
| Technical Lead | [Name] | [Telegram/Phone] | [TZ] |
| Security Lead | [Name] | [Telegram/Phone] | [TZ] |
| Operations Lead | [Name] | [Telegram/Phone] | [TZ] |
| Multisig Signer 1 | [Name] | [Telegram] | [TZ] |
| Multisig Signer 2 | [Name] | [Telegram] | [TZ] |

### External Support
- **Audit Firm**: [Contact info]
- **Legal Counsel**: [Contact info]
- **PR Agency**: [Contact info]

---

## =Ë Incident Response Checklist

### During Incident
- [ ] Pause affected contracts
- [ ] Alert core team
- [ ] Document everything
- [ ] Assess impact
- [ ] Develop fix
- [ ] Test solution
- [ ] Communicate status

### Post-Incident
- [ ] Deploy fixes
- [ ] Unpause contracts
- [ ] Publish report
- [ ] Compensate users (if applicable)
- [ ] Update procedures
- [ ] Schedule retrospective

---

## =à Technical Commands

### Emergency Pause
```bash
# Pause specific contract
cast send $CONTRACT "pause()" --private-key $EMERGENCY_KEY

# Pause via EmergencyPause (all contracts)
cast send $EMERGENCY_PAUSE "pauseAll()" --private-key $EMERGENCY_KEY
```

### Check Contract Status
```bash
# Check if paused
cast call $CONTRACT "paused()" --rpc-url $RPC_URL

# Check pause timestamp
cast call $CONTRACT "pausedAt()" --rpc-url $RPC_URL

# Calculate auto-unpause time (72 hours)
echo $(($(cast call $CONTRACT "pausedAt()") + 259200))
```

### Multisig Operations
```bash
# Submit transaction
cast send $MULTISIG "submitTransaction(address,uint256,bytes)" \
  $TARGET 0 $CALLDATA --private-key $SIGNER_KEY

# Confirm transaction
cast send $MULTISIG "confirmTransaction(uint256)" \
  $TX_ID --private-key $SIGNER_KEY

# Execute transaction (after confirmations)
cast send $MULTISIG "executeTransaction(uint256)" \
  $TX_ID --private-key $SIGNER_KEY
```

---

## =â Communication Templates

### Initial Alert (Internal)
```
=¨ SECURITY ALERT - [CRITICAL/HIGH/MEDIUM]

Time: [UTC timestamp]
Issue: [Brief description]
Impact: [Estimated affected users/funds]
Status: Investigating / Mitigating / Resolved

Actions taken:
- [Action 1]
- [Action 2]

Next steps:
- [Step 1]
- [Step 2]

Point person: [Name]
```

### Public Announcement
```
  System Maintenance Notice

We are currently investigating [general description].
User funds are [safe/being secured].

Actions taken:
- System paused as precaution
- Team investigating issue
- Updates every 30 minutes

Latest updates: [status page URL]
```

### Post-Incident Report
```
=Ê Incident Report - [Date]

Summary: [What happened]
Impact: [Who was affected and how]
Root cause: [Technical explanation]
Resolution: [How it was fixed]
Prevention: [Future measures]

Full details: [blog post URL]
```

---

## = Auto-Unpause Mechanism

All emergency pauses auto-expire after 72 hours to prevent permanent lock:

```solidity
modifier whenNotPaused() {
    require(!paused || block.timestamp > pausedAt + 72 hours, "Paused");
    _;
}
```

To unpause before expiry:
1. 3/5 multisig required
2. Document reason for unpause
3. Verify fix deployed
4. Monitor after unpause

---

## =Ý Lessons Learned Process

After each incident:

1. **Retrospective Meeting** (within 48 hours)
   - What went well?
   - What could improve?
   - Action items

2. **Update Procedures**
   - Revise this playbook
   - Update monitoring
   - Improve automation

3. **Share Knowledge**
   - Internal documentation
   - Community updates
   - Industry sharing (if applicable)

---

## <¯ Prevention Measures

### Monitoring Setup
- Transaction monitoring alerts
- Unusual volume detection
- Gas price anomaly alerts
- Social media monitoring

### Regular Drills
- Monthly pause/unpause test
- Quarterly full incident drill
- Annual third-party assessment

### Access Control
- Regular key rotation
- Access audit monthly
- Multisig signer verification
- Hardware wallet enforcement

---

**Remember**: Speed matters, but accuracy matters more. Take 30 seconds to think before acting. Document everything. Protect users first, protocol second.