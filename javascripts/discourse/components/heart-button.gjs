// components/heart-button.gjs
import {action} from "@ember/object";
import DButton from "discourse/components/d-button";
import {inject as service} from "@ember/service";
import {selectedNode, selectedRange, selectedText, } from "discourse/lib/utilities";
import PostTextSelection from "discourse/components/post-text-selection";
import {tracked} from "@glimmer/tracking";


export default class HeartButtonWrapper extends PostTextSelection {
    @tracked _disableLikeButton = false;
    // buttonDisabled = propertyEqual("_disableLikeButton", "true");

    @service appEvents;
    @service capabilities;
    @service currentUser;
    @service site;
    @service siteSettings;
    @service menu;

    get hideButton() {
        return this._disableLikeButton === true;
    }

    constructor() {
        super(...arguments);
        this.handleSelectionErrors.call(this);

    }
    <template>
        <div id="heart-quote-faker-wrapper">
            <DButton
                @icon="heart"
                @action={{this.onHeartClickedFaker}}
                @translatedTitle="Like"
                @translatedLabel="Like"
                @id="heart-quote-faker"
                @class="btn-flat quote-edit-label"
                @disabled={{this.hideButton}}
            />
        </div>
    </template>

    @action
    onHeartClickedFaker() {
        document.querySelector("#heart-button-trigger-prep").click();
        //this.doStuff();
    }

    doStuff() {
        const _selectedText = selectedText();
        const _selectedRange = selectedRange();
        const _selectedNode = selectedNode();

        console.log(_selectedText, '_selectedText');
        console.log(_selectedRange, 'selectedRange');
        console.log(_selectedNode, 'selectedNode');

        const { isIOS, isAndroid, isOpera } = this.capabilities;
        //console.log('CurrentUser', this.currentUser);
    }


    handleSelectionErrors() {
        const that = this;
        // This method looks at the current selection and shows errors in the UI accordingly.
        setTimeout(function () {
            const selection = window.getSelection();
            const commonAncestor = selection.getRangeAt(0).commonAncestorContainer;
            const articleNode = $(commonAncestor).closest(".boxed, .reply");
            const ariaLabel = articleNode[0].getAttribute('aria-label')

            console.log('handleSelectionErrors commonAncestor', commonAncestor)
            //that.doStuff();

            // destory tippy tooltip when selection changes
            const $heartButtonWrapper = $('#heart-quote-faker-wrapper');
            const $heartButton = $heartButtonWrapper.find('button').first();
            const $hansoftButton = $('#raise-hansoft-wrapper');

            if ($heartButtonWrapper[0]?.['_tippy']) {
                $heartButtonWrapper[0]['_tippy'].destroy();
            }

            if ($hansoftButton[0]?.['_tippy']) {
                $hansoftButton[0]['_tippy'].destroy();
            }

            //console.log('commonAncestor', commonAncestor);
            // run tests to provide feedback to user when they cannot select the like button
            if ((commonAncestor.nodeType === Node.ELEMENT_NODE && commonAncestor.classList.contains('heart-markup-wrapper')) || commonAncestor.parentNode.classList.contains('heart-markup-wrapper')) {
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection already liked. Select another entry.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButtonWrapper.data('tippy', instance);
                $heartButton.attr('disabled', true)
            }
            else if (selectedRange().commonAncestorContainer.parentElement.nodeName !== 'P' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'LI' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'H1' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'H2' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'H3' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'H4' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'H5' && selectedRange().commonAncestorContainer.parentElement.nodeName !== 'TD' && commonAncestor.nodeType !== Node.ELEMENT_NODE) {
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection must be within a paragraph, LI, heading or table cell.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButton.data('tippy', instance);
                $heartButton.attr('disabled', true)
            }
            else if (commonAncestor.nodeType === Node.ELEMENT_NODE && (commonAncestor.tagName === 'OL' || commonAncestor.tagName === 'UL')) {
                console.log('commonAncestor is OL or UL', commonAncestor);
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection has too many list elements. Select one list entry at a time.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButtonWrapper.data('tippy', instance);
                $heartButton.attr('disabled', true)
            } /* else if (commonAncestor.nodeType === Node.ELEMENT_NODE && (commonAncestor.tagName === 'LI' && !$(commonAncestor).find('code').length > 0)) {
              console.log('commonAncestor is LI', commonAncestor);
              this._disableLikeButton = true;
              const instance = tippy('#heart-quote-faker-wrapper', {
                  content: 'Selection too broad. Select one list entry at a time.',
                  allowHTML: false,
                  placement: 'top',
                  showOnCreate: false,
              });
              $heartButtonWrapper.data('tippy', instance);
              $heartButton.attr('disabled', true)
          } */ else if (commonAncestor.nodeType === Node.ELEMENT_NODE && (commonAncestor.tagName === 'LI' && $(commonAncestor).find('ul').length > 0)) {
                console.log('commonAncestor is LI but has Uls', commonAncestor);
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection too broad. Select one list entry at a time.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false
                });
                $heartButtonWrapper.data('tippy', instance);
                $heartButton.attr('disabled', true)
            } else if (commonAncestor.nodeType === Node.ELEMENT_NODE && (commonAncestor.tagName === 'DIV' && commonAncestor.className === 'cooked')) {
                console.log('Cooked is ancenstor');
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection too broad. Select one paragraph at a time.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButtonWrapper.data('tippy', instance);
                $heartButton.attr('disabled', true)
            } else if ($(commonAncestor).parents('.onebox-body').length || $(commonAncestor).parents('.embedded-posts').length || $(commonAncestor).parents('aside').length) {
                // disallow hearting for embedded posts, and special includes that dont really belong to the actual post
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Selection is not part of the actual post.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButtonWrapper.data('tippy', instance);
                $heartButton.attr('disabled', true)
                console.info("Like attempt detected but inside embedded post. Not allowing hearting.");
            } else if ($(commonAncestor).parent().find('.hansoftIcon').length) {

                // disallow hearting for embedded posts, and special includes that dont really belong to the actual post
                this._disableHansoftButtons = true;

                const instance1 = tippy('#raise-hansoft-wrapper', {
                    content: 'Section already has a reference to a Hansoft ticket.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                const instance2 = tippy('#link-hansoft-wrapper', {
                    content: 'Section already has a reference to a Hansoft ticket.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $hansoftButton.data('tippy', instance2);
            }

            if (settings.allow_like_own_content === false && ariaLabel.includes(this.currentUser.username)) {
                // Disable hearting for own posts
                this._disableLikeButton = true;
                const instance = tippy('#heart-quote-faker-wrapper', {
                    content: 'Hearting your own content is disabled.',
                    allowHTML: false,
                    placement: 'top',
                    showOnCreate: false,
                });
                $heartButtonWrapper.data('tippy', instance);
                console.info("Like attempt detected on own post. Not allowing hearting.");
            }

        }, 500)

    }

}