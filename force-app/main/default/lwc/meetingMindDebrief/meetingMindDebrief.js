import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import generateDebrief from '@salesforce/apex/GeminiDebriefService.generateDebrief';

const FIELDS = [
    'Meeting_Debrief__c.Sentiment__c',
    'Meeting_Debrief__c.Manager_Summary__c',
    'Meeting_Debrief__c.Key_Points__c',
    'Meeting_Debrief__c.Action_Items__c',
    'Meeting_Debrief__c.Next_Steps__c'
];

export default class MeetingMindDebrief extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    meetingNotes = '';
    isLoading = false;
    debriefData = null;
    errorMessage = '';
    
    debriefId;

    handleNotesChange(event) {
        this.meetingNotes = event.target.value;
    }

    handleGenerate() {
        if (!this.meetingNotes || this.meetingNotes.trim().length === 0) {
            this.errorMessage = 'Please provide meeting notes before generating a debrief.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.debriefData = null;
        this.debriefId = null;

        generateDebrief({ 
            meetingNotes: this.meetingNotes, 
            recordId: this.recordId, 
            objectType: this.objectApiName 
        })
        .then((resultId) => {
            this.debriefId = resultId;
            // The loading spinner will remain true until the @wire method fetches the new record
        })
        .catch((error) => {
            this.isLoading = false;
            this.errorMessage = error.body && error.body.message ? error.body.message : error.message;
        });
    }

    @wire(getRecord, { recordId: '$debriefId', fields: FIELDS })
    wiredDebriefRecord({ error, data }) {
        if (data) {
            this.debriefData = {
                Sentiment__c: data.fields.Sentiment__c.value,
                Manager_Summary__c: data.fields.Manager_Summary__c.value,
                Key_Points__c: data.fields.Key_Points__c.value,
                Action_Items__c: data.fields.Action_Items__c.value,
                Next_Steps__c: data.fields.Next_Steps__c.value
            };
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.errorMessage = error.body && error.body.message ? error.body.message : 'Failed to retrieve the newly generated debrief record.';
        }
    }

    get sentimentBadgeClass() {
        if (!this.debriefData) return 'slds-badge';
        const sentiment = this.debriefData.Sentiment__c;
        if (sentiment === 'Positive') return 'slds-badge slds-theme_success';
        if (sentiment === 'Negative') return 'slds-badge slds-theme_error';
        return 'slds-badge slds-theme_shade';
    }

    get debriefRecordUrl() {
        return this.debriefId ? `/lightning/r/Meeting_Debrief__c/${this.debriefId}/view` : '#';
    }
}
