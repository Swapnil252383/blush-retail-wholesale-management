import { LightningElement } from 'lwc';
import { open } from 'lightning/accApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BlushAgentforceLauncher extends LightningElement {
    isOpening = false;

    async handleOpen() {
        this.isOpening = true;

        try {
            // Opens the native Agentforce panel.
            // The user can select Blush Project Guide
            // from the agent picker if needed.
            await open();
        } catch (error) {
            const message =
                error?.body?.message ||
                error?.message ||
                'Unable to open the Agentforce panel.';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Agentforce could not open',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isOpening = false;
        }
    }
}