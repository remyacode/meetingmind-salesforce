@isTest
private class GeminiDebriefServiceTest {

    public class GeminiHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String dummyJson = '{"key_points":["Point 1","Point 2"],"action_items":["Action 1"],"next_steps":["Step 1"],"sentiment":"Positive","manager_summary":"Good meeting."}';
            
            String responseBody = '{' +
                '"candidates": [{' +
                    '"content": {' +
                        '"parts": [{' +
                            '"text": ' + JSON.serialize(dummyJson) +
                        '}]' +
                    '}' +
                '}]' +
            '}';
            res.setBody(responseBody);
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = acc.Id);
        insert opp;

        Case c = new Case(Subject = 'Test Case', AccountId = acc.Id);
        insert c;
    }

    @isTest
    static void testOpportunityDebrief() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GeminiHttpCalloutMock());
        Id debriefId = GeminiDebriefService.generateDebrief('Test notes', opp.Id, 'Opportunity');
        Test.stopTest();
        
        System.assertNotEquals(null, debriefId, 'Debrief ID should not be null');
        Meeting_Debrief__c debrief = [SELECT Meeting_Notes__c, Key_Points__c, Action_Items__c, Next_Steps__c, Sentiment__c, Manager_Summary__c, Status__c, Model_Used__c, Related_Opportunity__c FROM Meeting_Debrief__c WHERE Id = :debriefId];
        
        System.assertEquals('Test notes', debrief.Meeting_Notes__c);
        System.assertEquals('Point 1\nPoint 2', debrief.Key_Points__c);
        System.assertEquals('Action 1', debrief.Action_Items__c);
        System.assertEquals('Step 1', debrief.Next_Steps__c);
        System.assertEquals('Positive', debrief.Sentiment__c);
        System.assertEquals('Good meeting.', debrief.Manager_Summary__c);
        System.assertEquals('Generated', debrief.Status__c);
        System.assertEquals('gemini-2.5-flash', debrief.Model_Used__c);
        System.assertEquals(opp.Id, debrief.Related_Opportunity__c);
    }

    @isTest
    static void testAccountDebrief() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GeminiHttpCalloutMock());
        Id debriefId = GeminiDebriefService.generateDebrief('Test notes', acc.Id, 'Account');
        Test.stopTest();
        
        System.assertNotEquals(null, debriefId, 'Debrief ID should not be null');
        Meeting_Debrief__c debrief = [SELECT Related_Account__c FROM Meeting_Debrief__c WHERE Id = :debriefId];
        System.assertEquals(acc.Id, debrief.Related_Account__c);
    }

    @isTest
    static void testCaseDebrief() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GeminiHttpCalloutMock());
        Id debriefId = GeminiDebriefService.generateDebrief('Test notes', c.Id, 'Case');
        Test.stopTest();
        
        System.assertNotEquals(null, debriefId, 'Debrief ID should not be null');
        Meeting_Debrief__c debrief = [SELECT Related_Case__c FROM Meeting_Debrief__c WHERE Id = :debriefId];
        System.assertEquals(c.Id, debrief.Related_Case__c);
    }
}
