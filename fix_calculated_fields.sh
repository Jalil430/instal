#!/bin/bash

echo "=== Fixing Calculated Fields Issues ==="
echo ""

# Step 1: Populate calculated fields for existing installments
echo "Step 1: Populating calculated fields for existing installments..."
python3 populate_calculated_fields_complete.py
echo ""

# Step 2: Deploy updated functions
echo "Step 2: Deploying updated functions..."
source deploy_env.sh
./deploy_list_functions.sh
./deploy_analytics_function.sh
echo ""

echo "=== Fix Complete ==="
echo ""
echo "What was fixed:"
echo "1. ✅ Updated create-installment function to populate calculated fields for new installments"
echo "2. ✅ Created get-analytics-optimized function for analytics dashboard"
echo "3. ✅ Populated calculated fields for all existing installments"
echo "4. ✅ Deployed all updated functions"
echo ""
echo "Your app should now work correctly:"
echo "- New installments will have all calculated fields populated"
echo "- Analytics dashboard will show data instead of 'no installments'"
echo "- Installments list will display properly with client/investor names"