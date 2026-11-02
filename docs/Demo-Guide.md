# Blush – Step-by-Step Demo Guide

Each step creates new records and gives the exact values you should see. Run the steps in order, because later steps use the records from earlier ones.

**Before you start:** open the org (`sf org open --target-org MyDevOrg`) and pick the **Blush** app from the App Launcher (9-dot grid, top left).

---

## Part 1 – Products and automatic price books

### Step 1: Create a Jewellery product (both channels)
1. **Products** tab → **New**.
2. Fill in:
   - Product Name: `Silver Anklet`
   - Product Code: `20#101`
   - Active: ✔
   - Category: `Jewellery`
   - Sales Channel: move **Retail** and **Wholesale** to *Chosen*
   - Base Price: `600`
3. **Save**.

✅ **Check:** open the **Related** tab → **Price Books** list:

| Price Book | List Price |
|---|---|
| Standard Price Book | 600 |
| Blush Retail Price Book | 600 |
| Blush Wholesale Price Book | 420 (30% lower) |

The *Wholesale Price* field on the product also shows 420.

### Step 2: Create a Garment product (retail only)
Same as Step 1, with these values:
- Product Name: `Party Dress`
- Product Code: `10#101`
- Category: `Garments`
- Sales Channel: **Retail** only
- Base Price: `1800`

✅ **Check:** only the Standard and **Retail** price books are listed. There is no wholesale entry.

❌ **Error test:** create a product with a Sales Channel but no Base Price → *"Enter a Base Price greater than zero before assigning a Sales Channel."*

---

## Part 2 – Lead → Opportunity (lead is converted automatically)

### Step 3: Create a lead
1. **Leads** → **New**.
2. Fill in:
   - First Name: `Pooja`
   - Last Name: `Kale`
   - Company: `Pooja Kale`
   - Email: `pooja.kale@example.com`
   - Phone: `9811122233`
   - Lead Status: `Open - Not Contacted`
   - Customer Type: `Retail`
3. **Save**.

### Step 4: Create a Retail opportunity with the same email
1. **Opportunities** → **New** → record type **Retail** → **Next**.
2. Fill in:
   - Opportunity Name: `Pooja Kale - Party Shopping`
   - Close Date: any date next week
   - Stage: `Prospecting`
   - **Leave Account Name empty**
   - Customer Details section:
     - Customer Name: `Pooja Kale`
     - Customer Email: `pooja.kale@example.com`
     - Customer Phone: leave empty
3. **Save**.

✅ **Check:**
- **Account Name** = *Pooja Kale* (filled in automatically).
- **Customer Contact** = Pooja Kale.
- **Price Book** = *Blush Retail Price Book* (see the Products related list).
- Open **Leads** → *Pooja Kale*: the lead now shows as **Converted**.
- Open **Accounts** → *Pooja Kale*: its record type is **Retail (B2C)**.
- Under **Opportunities** there is only **one** opportunity for Pooja, because conversion did not create a second one.

### Step 5: Add products to the opportunity
1. On the opportunity → **Products** related list → **Add Products**.
2. Tick **Silver Anklet** and **Party Dress** → **Next**.
3. Enter quantities:
   - Silver Anklet: `2`
   - Party Dress: `1`
4. Keep the sales prices (600 and 1800) → **Save**.

❌ **Error test (wrong channel):** New Retail opportunity → Account Name = `Fashion Hub Traders` (a wholesale account) → Save → *"A Retail opportunity must be linked to a Retail account."*

---

## Part 3 – Retail order, GST, discount approval, payment, invoice

### Step 6: Create the order from the opportunity
1. **Orders** → **New** → record type **Retail** → **Next**.
2. Fill in:
   - Account Name: `Pooja Kale`
   - Order Start Date: today
   - Status: `Draft`
   - Opportunity (in *Blush Sales & Payment*): `Pooja Kale - Party Shopping`
3. **Save**.

✅ **Check:**
- **Order Products** already contains Silver Anklet ×2 and Party Dress ×1, copied from the opportunity.
- **Store** = Blush - FC Road (the default store).
- **Sales Representative** = the opportunity owner.
- **Tax Type** = CGST + SGST. Pooja has no address, so she is treated as a Maharashtra counter sale.

Refresh the page and check the totals:

| Field | Value | Why |
|---|---|---|
| Effective Order Amount | 3,000.00 | 1,200 + 1,800 |
| Total CGST | 126.00 | half of the GST |
| Total SGST | 126.00 | half of the GST |
| Total GST | 252.00 | Anklet 3% of 1,200 = 36; Dress 12% of 1,800 = 216 (above Rs. 1,000) |
| Total Amount Payable | 3,252.00 | 3,000 + 252 |
| Commission | 30.00 | amount is above Rs. 1,000, so flat Rs. 30 |

### Step 7: Give discounts (one above 10%)
1. In **Order Products**, open **Party Dress** → **Edit** → *Discount (per unit)* = `150` → **Save**. That is 8.33%, so no approval is needed.
2. Go back to the order, open **Silver Anklet** → **Edit** → *Discount (per unit)* = `90` → **Save**. That is 15%, so approval is needed.

✅ **Check the order:**

| Field | Value |
|---|---|
| Total Discount | 330.00 (90×2 + 150) |
| Max Line Discount % | 15% |
| Effective Order Amount | 2,670.00 |
| Total CGST / SGST | 114.30 / 114.30 |
| Total GST | 228.60 (Anklet 3% of 1,020 = 30.60; Dress 12% of 1,650 = 198) |
| Total Amount Payable | 2,898.60 |
| **Discount Approval Status** | **Pending** (submitted automatically) |

### Step 8: Try to mark it paid before approval (should fail)
**Edit** the order → Payment Mode = `UPI`, Payment Status = `Paid` → **Save**.

❌ *"A line discount above 10% must be approved before the order is activated or marked as Paid."* Click **Cancel**.

### Step 9: Approve the discount
1. Bell icon 🔔 (top right) → click the approval request.
   (Or App Launcher → search **Approval Requests**.)
2. Click **Approve** → add a comment → **Approve**.

✅ **Check:** the order's **Discount Approval Status** = **Approved**.

### Step 10: Mark it paid
**Edit** the order → Payment Mode = `UPI`, Payment Status = `Paid` → **Save**. This now succeeds.

❌ **Error test:** set Payment Status = Paid with no Payment Mode → *"Select a Payment Mode before marking the order as Paid."*

### Step 11: Generate the invoice PDF
1. On the order, click **Generate Invoice** (top-right action buttons).
2. Click **Preview PDF**. The invoice opens in a new tab:
   - Store name, address, GSTIN, phone and website
   - Invoice No. `INV-000001xx`, date, Payment Mode UPI
   - To: Pooja Kale
   - Line table: Sr. No., Product Code, Description, Qty, Unit Price, Discount, GST %, **CGST**, **SGST**, Net Price
   - Totals ending in **Total Amount Payable Rs. 2,898.60**
3. Back on the order → **Generate Invoice** → **Save PDF to Order**.

✅ **Check:** the order's **Files** list now contains `INV-000001xx.pdf`.

---

## Part 4 – Wholesale customer outside Maharashtra (IGST, 1% commission)

### Step 12: Wholesale opportunity for a brand-new customer
1. **Opportunities** → **New** → **Wholesale** → **Next**.
2. Fill in:
   - Opportunity Name: `Rao Fashions - Anklet Stock`
   - Close Date: next week
   - Stage: `Prospecting`
   - Account Name: empty
   - Customer Name: `Arjun Rao`
   - Customer Email: `arjun@raofashions.example.com`
   - Customer Phone: `9000011111`
   - Company Name: `Rao Fashions`
3. **Save**.

✅ **Check:**
- A new account **Rao Fashions** of type **Wholesale (B2B)** has been created.
- Contact *Arjun Rao* has been created.
- **Price Book** = Blush Wholesale Price Book.

### Step 13: Give the account a Karnataka address
**Accounts** → *Rao Fashions* → **Edit** → Billing Address:
- Street: `45 Commercial Street`
- City: `Bengaluru`
- Country: `India`
- State: `Karnataka`
- Zip: `560001`

**Save**.

### Step 14: Wholesale order with products added directly
1. **Orders** → **New** → **Wholesale** → Account `Rao Fashions`, Order Start Date today, Status `Draft`, Opportunity `Rao Fashions - Anklet Stock` → **Save**.
2. **Order Products** → **Add Products**.
   - **Party Dress is not listed**, because it is retail only.
   - Tick **Silver Anklet** → **Next** → Quantity `2`. The unit price is 420 (wholesale) → **Save**.

✅ **Check:**

| Field | Value |
|---|---|
| Billing address | copied from the account (Karnataka) |
| Tax Type | **IGST** |
| Effective Order Amount | 840.00 |
| Total IGST | 25.20 (3%) |
| Total CGST / SGST | 0 / 0 |
| Total Amount Payable | 865.20 |
| **Commission** | **8.40** (1% because the amount is ≤ Rs. 1,000) |

3. **Edit** → Payment Mode `Cash`, Payment Status `Paid` → **Save**.
4. **Generate Invoice** → **Preview PDF**. The invoice shows a single **IGST** column with no CGST/SGST.

### Step 15: Tax changes when the address changes
Create another Wholesale draft order for Rao Fashions with 1 Silver Anklet. Then **Edit** the order → change Billing State to `Maharashtra` → **Save**.

✅ **Check:** Tax Type = CGST + SGST, and the IGST amount has moved into CGST/SGST (6.30 + 6.30).

---

## Part 5 – Paid order lock for sales reps

### Step 16: A sales rep cannot edit a paid order
1. **Setup** (gear icon) → **Users** → **Sneha Patil** → **Login**.
   If the Login button is missing: Setup → *Login Access Policies* → tick *Administrators Can Log in as Any User*.
2. As Sneha, open **Orders** → order **00000101** (Anita Desai, Paid, owned by Sneha) → **Edit** → change Description → **Save**.

❌ *"This order has been paid and can no longer be edited."*

3. Delete the order → ❌ *"Paid orders cannot be deleted."*
4. Log out (top right *Log out as Sneha Patil*). As admin, which includes the Edit Paid Orders permission, you **can** edit it.

---

## Part 6 – Campaigns (Marketing)

### Step 17: Create a campaign for this month
1. **Campaigns** → **New**.
2. Fill in:
   - Campaign Name: `Navratri Special`
   - Active: ✔
   - Type: `Advertisement`
   - Status: `In Progress`
   - Start Date: the 1st of this month
   - End Date: the last day of this month
   - Budgeted Cost: `25000`
3. **Save**.
4. Create a second campaign, `Christmas Offer`, with Start Date 1 Dec and End Date 31 Dec.

### Step 18: Current-month view
**Campaigns** → list view dropdown → **Campaigns This Month**.

✅ **Check:** *Navratri Special* and *Diwali Festive Sale* are listed. *Christmas Offer* and *Monsoon Clearance* are **not**.

Optional: on *Navratri Special* → **Campaign Members** → **Add Leads** → add *Meera Nair*.

---

## Part 7 – Nightly follow-up reminder

### Step 19: Create an overdue task
1. Open the opportunity `Rao Fashions - Anklet Stock` (still open).
2. **Activity** → **New Task**:
   - Subject: `Call Arjun for confirmation`
   - Due Date: **2 days ago**
   - Status: `Not Started`
3. **Save**.
4. On `Pooja Kale - Party Shopping`, create a task with a Due Date **10 days ago**.

### Step 20: Run the job now
The job runs every night at 1 AM. To run it immediately, use VS Code:
```powershell
sf apex run --target-org MyDevOrg --file scripts/apex/run-followup-now.apex
```
Or use **Developer Console** (gear → Developer Console) → *Debug* → *Open Execute Anonymous Window* → paste `Database.executeBatch(new OpportunityFollowUpBatch());` → **Execute**.

✅ **Check:** after about 10 seconds, refresh *Rao Fashions - Anklet Stock* → Activity shows **"Follow up: open opportunity has pending activities"** (High priority, due today, assigned to the opportunity owner).
- *Pooja Kale - Party Shopping* gets **no** reminder, because its task is older than 5 days.
- Run the job again: still only **one** reminder per opportunity.

---

## Part 8 – Reports

**Reports** tab → **All Folders** → **Blush Reports**. Your Step 10 and Step 14 orders are included because they are **Paid** and dated this year.

| Report | What to look for |
|---|---|
| **Monthly Commission by Sales Rep** | This month: your rep row includes 30.00 (Pooja) + 8.40 (Rao). Reps are sorted highest first within each month, so the top 3 are at the top |
| **Top Reps by Commission - This Month** | Commission per rep for the current month |
| **Quarterly Revenue Statement** | Per quarter and channel: Quantity, Assumed Revenue (retail ₹200 / wholesale ₹140 per unit), Assumed Cost (₹100), Assumed Profit |
| **Monthly Order Report** | Every order per month, with net amount totals |
| **Retail vs Wholesale Monthly Amount** | Matrix of Retail/Wholesale × month, plus a **Previous Month Amount** column |
| **Total GST Payable** | CGST, SGST, IGST and total GST per month |
| **Top 10 Products by Net Sales Quantity** | Silver Anklet now appears with 4 units |
| Retail / Wholesale – Monthly Sales, Commission by Rep, Top Products | Channel versions used by the dashboards |
| Campaigns This Month, Campaign Performance, Leads by Source - This Month | Marketing reports |

## Part 9 – Dashboards

**Dashboards** tab → **All Folders** → **Blush Dashboards**. Open each one and click **Refresh** (top right), because dashboards show cached data until refreshed.

| Dashboard | Components |
|---|---|
| **Blush Retail Dashboard** | Retail sales this year (metric), monthly retail sales, top 3 reps by commission, top 10 products, retail vs wholesale |
| **Blush Wholesale Dashboard** | The same components for wholesale |
| **Blush Marketing Dashboard** | Campaigns this month by status, leads by campaign type, new leads by source, top products |

---

## Quick checklist

| Requirement | Step |
|---|---|
| Retail/wholesale records distinguished | 4, 12 |
| Capture customer name/email/phone on opportunity | 4, 12 |
| Lead found and converted / customer created | 4, 12 |
| Price books, wholesale 30% lower, no admin setup | 1, 2 |
| Retail uses retail pricing and accounts | 4, 5, 14 |
| Campaigns and current-month view | 17, 18 |
| Nightly follow-up reminder | 19, 20 |
| Commission 1% / flat Rs. 30 | 6, 14 |
| Paid orders locked for reps | 16 |
| Invoice PDF | 11, 14 |
| Discount > 10% needs approval | 7, 8, 9 |
| GST by category, CGST/SGST vs IGST | 6, 14, 15 |
| Reports and dashboards | Parts 8, 9 |
