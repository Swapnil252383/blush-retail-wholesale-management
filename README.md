# Blush – Salesforce Retail & Wholesale Management

Salesforce DX project for the Blush Phase 1 mini project: customers and leads, retail/wholesale opportunities and orders, two-channel pricing, GST invoices, discount approval, commissions, follow-up reminders, reports and dashboards.

- Solution design, assumptions and walkthrough: [docs/Solution-Design.md](docs/Solution-Design.md)
- Apex test evidence (83 tests, 100% coverage of Blush code): [docs/Test-Evidence.md](docs/Test-Evidence.md)
- Sample invoice: [docs/Sample-Invoice-INV-00000100.pdf](docs/Sample-Invoice-INV-00000100.pdf)

## Project layout

| Path | Contents |
|---|---|
| `force-app/main/default/classes` | Services, batch, invoice controller and test classes |
| `force-app/main/default/triggers` | `Product2Trigger`, `OpportunityTrigger`, `OrderTrigger`, `OrderItemTrigger` |
| `force-app/main/default/objects` | Custom fields, record types, validation rules, `Store__c`, `GST_Rate__mdt` |
| `force-app/main/default/pages` / `lwc` | `BlushInvoice` PDF page and the `generateInvoice` quick action |
| `force-app/main/default/approvalProcesses`, `workflows` | Order discount approval and its field updates |
| `force-app/main/default/reports`, `dashboards`, `reportTypes` | Blush Reports / Blush Dashboards |
| `force-app/main/default/permissionsets`, `profiles`, `applications` | Access model and the Blush app |
| `scripts/apex` | Org setup scripts (users, demo data, scheduling, sample invoice) |
| `data/Blush_Products.csv` | Sample product catalogue |

## Set up a new org

```bash
# 1. Authenticate (opens the browser)
sf org login web --alias MyDevOrg --set-default

# 2. Org prerequisites (Setup, one time)
#    - Order Settings: Enable Orders
#    - Approver user: edit approvalProcesses/Order.Order_Discount_Approval and dashboards runningUser
#      if the admin username differs from the one in this repo

# 3. Deploy
sf project deploy start --source-dir force-app --target-org MyDevOrg

# 4. Give the admin field access and the Marketing User feature
sf org assign permset --name Blush_Manager --target-org MyDevOrg
#    Setup > Users > (admin) > tick "Marketing User"

# 5. Users, demo data, nightly job
sf apex run --file scripts/apex/create-users.apex --target-org MyDevOrg
sf apex run --file scripts/apex/setup-demo-data.apex --target-org MyDevOrg
sf apex run --file scripts/apex/schedule-jobs.apex --target-org MyDevOrg

# 6. Run tests
sf apex run test --target-org MyDevOrg --test-level RunLocalTests --code-coverage --wait 30
```

**Redeploying Apex later:** Salesforce blocks Apex deployments while the nightly job is scheduled. Either delete the job *Blush - Opportunity Follow-up (nightly)* under Setup > Scheduled Jobs and rerun `schedule-jobs.apex` afterwards, or enable *Allow deployments of components when corresponding Apex jobs are pending or in progress* in Setup > Deployment Settings.

The setup script activates the Standard Price Book, creates the two Blush price books and stores, and loads the catalogue. Price book entries are created automatically by the product trigger.
