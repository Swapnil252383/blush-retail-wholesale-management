import { LightningElement, api } from 'lwc';
import { open } from 'lightning/accApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BlushAgentforceFab extends LightningElement {
    @api botId;

    isOpening = false;

    async handleOpenChat() {
        if (this.isOpening) {
            return;
        }

        this.isOpening = true;

        try {
            const agentId = this.botId?.trim();

            if (agentId) {
                // Open the specific Blush agent.
                await open(agentId);
            } else {
                // Open the last-used Agentforce agent.
                await open();
            }
        } catch (error) {
            const message =
                error?.body?.message ||
                error?.message ||
                'Unable to open Agentforce. Check your access and agent status.';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not open chatbot',
                    message: message,
                    variant: 'error'
                })
            );
        } finally {
            this.isOpening = false;
        }
    }
}