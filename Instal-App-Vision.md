This is a file that should give you understanding of our app Instal.

Instal - is an app for tracking islamic installments.

Design - Very modern, compact (for big screens/desktop), informative, simplistic and professional.

Flutter - mac, windows, linux.
Yandex for auth and database. (FOr now just local database, we will implement this in the future)

Main features: 
 Navigation - app should have left sidebar which shows only icons, and shows names of the screens when hovered over. it should be always there for quick navigation between main screens (Installments, Clients, Investors). **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

 Installemnts - 
  functionality: installment table should have id, userid, client(for linking installments to clients), investor(for linking to investors), product name(name of the product that is selled in the installment), cash price(price when buying without installment), installment price(price when buying with installment), term(for how months the installemnt lasts), down payment, monthly payment(price the client needs to pay every month), date for down payment, date for installment start(like client can make a down payment at 10s of March and might want to start the installment from 1st of April, or any other different date, that's why we need this one), installment end date(this is basically the last month date), in the app we also will show installment start date which will basically be a down payment date field. 
  
  We will also need to have separate table for installment payments, they should have id, installment(for linking payments to installments), payment number(like from 0 to whatever months we have set in installemnt's to which these payments connected term. Like if term 6 months, then we should be creating 6 installment payments from 0 to 5, where 0 is down payment and others are months from 1 to 5, and if the installment without down payment then 0 won't be a down payment but 1st month, from 1st to 6th will be in this case), due date, expected amount, paid amount(the amount actually paid), status(which will either be оплачено, предстоящий, к оплате (which will happen when tha payment due date is today or yesterday), просрочено (when it's over 2 days from due date)), paid Date(when client actually paid).

  screens: installemnts list screen, installment details screen, add installment screen. 
   The list screen should have a list view that shows all the installments in it, it should be compact and informative and progfessional. Also should have slim top bar that has search functionality and sort installments by status, creation date, amount, client. list view's item should show client name, product name, payed, and left amount, next installment payment section at the right side with the payment number (can be named month 1,2,3... or a down payment), due date, status and ability to click on it to register payment and down arrow with a dropdown of all installment payments. The list view's item should be right clickable that will open a small dropdown menu with different quick actions, like delete, select, add payment etc. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

   The installment details screen opens when installment item is clicked, should show installment info (all installment model data and more), and at the bottom list of installment payments like down payment, month 1,2,3 and so on. this list's item should show info about installment payments. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**
   
   The add installment screen should have fields: Client, Investor, Product name, Cash price, Installment Price, Term (Months), Down payment, Monthly payment, Buying date(when client payed down payment or if without down payment when the installment was made), Installment start date(like client can make a down payment at 10s of March and might want to start the installment from 1st of April). and then add installemnt button. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

 Clients - 
   functionality: CLient model should have: id, userid, full name, contact number, passport number, adress. Client should be used when creating installments, when creating installment you can choose from existing clients.

   Screens: clients list screen, client details screen, add and edit installment screens.
   The clients list screen should have a list view of clients, it should be compact and informative and professional. Also should have slim top bar that has search functionality and sort client by creation date, A-Z. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

   THe client details screen similarly to installment details screen opens when client item is clicked, should show client info (all client model data and more), and at the bottom list of installments attached to the client we have opened, with the same item as in installments screen. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

   The add and edit installment screens should have fields: full name, contact number, passport number, adress. and then add or edit installment button. **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**

 Investors - Investor model should have: id, userid, full name, investment amount, investor percentage, user precentage. Investor should be used when creating installments, when creating installment you can choose from existing investors. 
 The investor should have same exact screens as the client screens, investors list screen, investor details screen, add and edit screens. inside they should be similar to clients screens description too.  **It also should follow the design principles "Very modern, compact (for big screens/desktop), informative, simplistic and professional."**