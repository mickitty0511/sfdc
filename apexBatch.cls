//Database.Statefulがあると、execute中に操作した変数に情報が保存された状態で参照できる。
public class apexBatch implements Database.Batchable<sObject>, Database.Stateful{
   	Map<Id, String> errorMap;
    Map<Id, SObject> IdToSObjectMap;
            
    //コンストラクタ
    public apexBatch(){
        errorMap = new Map<Id, String>();
        IdToSObjectMap = new Map<Id, SObject>();
    }
    
    /*
     * @description バッチ処理にかけるレコードを取得
     * @param bc Database.BatchableContext
     */
    public Database.QueryLocator start(Database.BatchableContext bc){
        System.debug('apexBatch起動');
        String query = 'SELECT Id, Name, Amount FROM Opportunity WHERE Amount >= 2000'; //取得したいレコードと条件をお好みで設定してください。
        return Database.getQueryLocator(query);
    }
    
    /*
     * @description 商談の金額を2000円にする。
     *                        (finishメソッドでメールを送信するために、2000円にすると入力規則でエラーが発生する設定を予め入れています。)
     * @param bc Database.BatchableContext
     * @param opplist startメソッドで取得した商談レコードのリスト
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> opplist){
        
        System.debug('executeメソッド起動');
        List<Opportunity> updated_list = new List<Opportunity>();
        for(Opportunity opp : opplist){
            opp.Amount = 1000;
            updated_list.add(opp);
        }
        List<Database.SaveResult> sr_list = Database.update(updated_list, false);
        Integer index = 0;
        for(Database.SaveResult sr : sr_list){
            if(!sr.isSuccess()){
                String errMsg = sr.getErrors()[0].getMessage();
                Id updated_record_id = updated_list[index].Id;
                errorMap.put(updated_record_id, errMsg);
                Opportunity updated_opp = updated_list[index];
                IdToSObjectMap.put(updated_record_id, updated_opp);
            }
            index++;
        }
        System.debug('executeメソッド終了');
        System.debug(errorMap.isEmpty());
    }
    
    /*
     * @description 対象の商談レコードのうち更新中にエラーが発生したものをメールに添付
     * @param bc Database.BatchableContext
     */
    public void finish(Database.BatchableContext bc){
        if(!errorMap.isEmpty()){ //Database.StatefulがないとerrorMap.isEmpty()がtrueになるため、if文内の処理を通らない。
            AsyncApexJob a = [SELECT id, ApexClassId,
                              JobItemsProcessed, TotalJobItems,
                              NumberOfErrors, CreatedBy.Email
                              FROM AsyncApexJob
                              WHERE id = :bc.getJobId()];
            String body = 'Your batch job '
                + 'apexBatch '
                + 'has finished. \n' 
                + 'There were '
                + errorMap.size()
                + ' errors. Please check the error list.';
            
            // エラーが発生したレコードの情報をCSVに記載
            String finalstr = 'Id, Name, Error \n';
            String subject = '商談- Apex バッチエラーリスト';
            String attName = 'Opportunity Errors.csv';
            for(Id id  : errorMap.keySet()){
                string err = errorMap.get(id);
                Opportunity opp = (Opportunity) IdToSObjectMap.get(id);
                string recordString = '"'+id+'","'+opp.Name+'","'+err+'"\n';
                finalstr = finalstr +recordString;
            } 
            
            // メール作成
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
            
            // エラーが発生したレコード情報を記載するファイルの設定 
            Messaging.EmailFileAttachment email_attachment = new Messaging.EmailFileAttachment();
            email_attachment.setFileName(attName);
            email_attachment.setBody(Blob.valueOf(finalstr));
            
            // 送付するメールへ設定
            String target_address = System.Label.FromAddress; ///組織のメールアドレスに設定したものを入れておきます。(※カスタム表示ラベルに入れておくと管理しやすい)
            Id address_id = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :target_address][0].Id; //
            email.setOrgWideEmailAddressId(address_id);
            email.setSubject( subject );
            email.setToAddresses( new String[] {a.CreatedBy.Email} );
            email.setPlainTextBody( body );
            email.setFileAttachments(new Messaging.EmailFileAttachment[] {email_attachment});
            
            // メール送付
            Messaging.SendEmailResult [] emailr = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});   
        }
        System.debug('apexBatch終了');
        
    }
}
