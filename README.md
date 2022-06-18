apexBatch.cls has a sample batch code where queried opportunities records are updated.

During executing its "start" method, programs store each error on updating opportunities.

On its "finish" method, stored errors are written on a csv file, 
then Salesforce send a email attached with the csv file.

In order to send emails from Salesforce, you need to register an email address as Organization-Wide Email Addresses. 