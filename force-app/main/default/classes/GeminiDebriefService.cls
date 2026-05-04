public with sharing class GeminiDebriefService {

    @AuraEnabled
    public static Id generateDebrief(String meetingNotes, String recordId, String objectType) {
        try {
            String apiKey;
            // Provide a mock API key during test execution to avoid QueryException if Custom Metadata isn't deployed yet
            if (Test.isRunningTest()) {
                apiKey = 'test-api-key';
            } else {
                MeetingMind_Config__mdt config = [
                    SELECT Gemini_API_Key__c 
                    FROM MeetingMind_Config__mdt 
                    WHERE DeveloperName = 'Default' 
                    LIMIT 1
                ];
                apiKey = config.Gemini_API_Key__c;
            }

            String prompt = 'Analyze these meeting notes. Return ONLY a valid JSON object with ' +
                'these exact keys: key_points (array of strings, max 5 items), ' +
                'action_items (array of strings, max 5 items), next_steps (array of ' +
                'strings, max 3 items), sentiment (exactly one of: Positive / Neutral ' +
                '/ Negative / Mixed), manager_summary (string max 200 chars). ' +
                'Meeting notes: ' + meetingNotes;

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Gemini_API/v1beta/models/gemini-2.5-flash:generateContent?key=' + apiKey);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);

            Map<String, Object> textMap = new Map<String, Object>{ 'text' => prompt };
            Map<String, Object> partsMap = new Map<String, Object>{ 'parts' => new List<Object>{ textMap } };
            Map<String, Object> contentsMap = new Map<String, Object>{ 'contents' => new List<Object>{ partsMap } };
            req.setBody(JSON.serialize(contentsMap));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() >= 400) {
                throw new CalloutException('API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }

            Map<String, Object> parsedRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> candidates = (List<Object>) parsedRes.get('candidates');
            if (candidates == null || candidates.isEmpty()) {
                throw new CalloutException('No candidates returned from Gemini API.');
            }
            
            Map<String, Object> candidate = (Map<String, Object>) candidates[0];
            Map<String, Object> content = (Map<String, Object>) candidate.get('content');
            List<Object> parts = (List<Object>) content.get('parts');
            Map<String, Object> part = (Map<String, Object>) parts[0];
            String jsonResult = (String) part.get('text');

            // Clean json text if it has markdown formatting
            if (jsonResult.startsWith('```json')) {
                jsonResult = jsonResult.substringAfter('```json').substringBeforeLast('```');
            } else if (jsonResult.startsWith('```')) {
                jsonResult = jsonResult.substringAfter('```').substringBeforeLast('```');
            }
            jsonResult = jsonResult.trim();

            Map<String, Object> structuredData = (Map<String, Object>) JSON.deserializeUntyped(jsonResult);

            List<Object> keyPointsObj = (List<Object>) structuredData.get('key_points');
            List<Object> actionItemsObj = (List<Object>) structuredData.get('action_items');
            List<Object> nextStepsObj = (List<Object>) structuredData.get('next_steps');
            
            String keyPoints = joinList(keyPointsObj, '\n');
            String actionItems = joinList(actionItemsObj, '\n');
            String nextSteps = joinList(nextStepsObj, '\n');
            String sentiment = (String) structuredData.get('sentiment');
            String managerSummary = (String) structuredData.get('manager_summary');

            Meeting_Debrief__c debrief = new Meeting_Debrief__c(
                Meeting_Notes__c = meetingNotes,
                Key_Points__c = keyPoints,
                Action_Items__c = actionItems,
                Next_Steps__c = nextSteps,
                Sentiment__c = sentiment,
                Manager_Summary__c = managerSummary,
                Status__c = 'Generated',
                Model_Used__c = 'gemini-2.5-flash'
            );

            if (objectType == 'Opportunity') {
                debrief.Related_Opportunity__c = recordId;
            } else if (objectType == 'Account') {
                debrief.Related_Account__c = recordId;
            } else if (objectType == 'Case') {
                debrief.Related_Case__c = recordId;
            }

            // Insert the record with sharing enforced (by class modifier)
            insert debrief;

            return debrief.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Debrief failed: ' + e.getMessage());
        }
    }

    private static String joinList(List<Object> objList, String separator) {
        if (objList == null || objList.isEmpty()) {
            return '';
        }
        List<String> strList = new List<String>();
        for (Object obj : objList) {
            if (obj != null) {
                strList.add(String.valueOf(obj));
            }
        }
        return String.join(strList, separator);
    }
}
