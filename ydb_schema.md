# YDB Database Schema

This document contains the complete schema for all tables in the Instal application YDB database.

## Table: users
**Primary Key:** id

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | Utf8 | NOT NULL | — |
| email | Utf8 | NOT NULL | — |
| password_hash | Utf8 | NOT NULL | — |
| full_name | Utf8 | NOT NULL | — |
| phone | Utf8 | — | — |
| created_at | Utf8 | NOT NULL | — |
| updated_at | Utf8 | NOT NULL | — |

## Table: clients
**Primary Key:** id

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | Utf8 | — | — |
| user_id | Utf8 | — | — |
| full_name | Utf8 | — | — |
| contact_number | Utf8 | — | — |
| passport_number | Utf8 | — | — |
| address | Utf8 | — | — |
| created_at | Timestamp | — | — |
| updated_at | Timestamp | — | — |

## Table: investors
**Primary Key:** id

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | Utf8 | — | — |
| user_id | Utf8 | — | — |
| full_name | Utf8 | — | — |
| investment_amount | Decimal(22,9) | — | — |
| investor_percentage | Decimal(22,9) | — | — |
| user_percentage | Decimal(22,9) | — | — |
| created_at | Timestamp | — | — |
| updated_at | Timestamp | — | — |

## Table: installments
**Primary Key:** id

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | Utf8 | — | — |
| user_id | Utf8 | — | — |
| client_id | Utf8 | — | — |
| investor_id | Utf8 | — | — |
| product_name | Utf8 | — | — |
| cash_price | Decimal(22,9) | — | — |
| installment_price | Decimal(22,9) | — | — |
| term_months | Int32 | — | — |
| down_payment | Decimal(22,9) | — | — |
| monthly_payment | Decimal(22,9) | — | — |
| down_payment_date | Date | — | — |
| installment_start_date | Date | — | — |
| installment_end_date | Date | — | — |
| created_at | Timestamp | — | — |
| updated_at | Timestamp | — | — |

## Table: installment_payments
**Primary Key:** Not explicitly shown

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| id | Utf8 | — | — |
| installment_id | Utf8 | — | — |
| payment_number | Int32 | — | — |
| due_date | Date | — | — |
| expected_amount | Decimal(22,9) | — | — |
| is_paid | Bool | — | — |
| paid_date | Date | — | — |
| created_at | Timestamp | — | — |
| updated_at | Timestamp | — | — |

## Table: whatsapp_settings
**Primary Key:** Not explicitly shown

| Column | Type | Constraints | Default |
|--------|------|-------------|---------|
| user_id | Utf8 | NOT NULL | — |
| green_api_instance_id | Utf8 | — | — |
| green_api_token | Utf8 | — | — |
| reminder_template_7_days | Utf8 | — | — |
| reminder_template_due_today | Utf8 | — | — |
| reminder_template_manual | Utf8 | — | — |
| is_enabled | Bool | — | — |
| created_at | Timestamp | — | — |
| updated_at | Timestamp | — | — |

## Relationships

Based on the schema structure, the following relationships exist:

### Foreign Key Relationships:
- `clients.user_id` → `users.id`
- `investors.user_id` → `users.id`
- `installments.user_id` → `users.id`
- `installments.client_id` → `clients.id`
- `installments.investor_id` → `investors.id`
- `installment_payments.installment_id` → `installments.id`
- `whatsapp_settings.user_id` → `users.id`

### Entity Relationships:
1. **Users** can have multiple **Clients**, **Investors**, and **Installments**
2. **Installments** belong to one **User**, one **Client**, and one **Investor**
3. **Installment Payments** belong to one **Installment** (payment schedule)
4. **WhatsApp Settings** belong to one **User** (notification preferences)

## Notes:
- All timestamp fields appear to use either `Timestamp` or `Utf8` types
- Decimal fields use `Decimal(22,9)` precision for financial calculations
- Primary keys are typically `Utf8` type (likely UUIDs)
- The `users` table has more NOT NULL constraints compared to other tables
- Date fields use the `Date` type for date-only values
- Boolean fields use the `Bool` type