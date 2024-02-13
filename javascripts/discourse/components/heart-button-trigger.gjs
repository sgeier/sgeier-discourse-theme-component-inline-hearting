// components/heart-button.gjs
import {action} from "@ember/object";
import {inject as service} from "@ember/service";
import {getOwner} from "@ember/application";
import {selectedText, } from "discourse/lib/utilities";
import PostTextSelection from "discourse/components/post-text-selection";
import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";
import {ajax} from "discourse/lib/ajax";


export default class HeartButtonTrigger extends PostTextSelection {
    constructor() {
        super(...arguments);
        const context = this;

        setTimeout(() => {
            console.log("Hearting component loaded...");

            document.querySelector("#heart-button-trigger-prep").addEventListener("click", this.onHeartButtonClickedPrep.bind(this));
            document.querySelector("#heart-button-trigger").addEventListener("click", this.onHeartButtonClicked.bind(this));

            // handler for clicking hearts
            $('#main-outlet').on('click', '.heartIcon', (event) => {
                setTimeout(() => this.handleHeartClick(event, context), 10);
            });

            // handler for showing tooltips when hovering hearts
            $('#main-outlet').on('mouseover', '.heartIcon[data-users]', this.hoverEventHeart);

            $('#main-outlet').on('mouseover', '.apollo-video-anchor .video-thumb-wrapper', (event) => {
                setTimeout(() => this.hoverVideoThumbs(event, context), 10);
            });
        }, 1000);

        this.initApi();
    }
    <template>
        <div id="heart-button-trigger"></div>
        <div id="heart-button-trigger-prep"></div>
    </template>

    @service appEvents;
    @service api;
    @service capabilities;
    @service currentUser;
    @service site;
    @service siteSettings;
    @service menu;

    likedMapping = [];
    topicId = null;
    heartIcon = $('<span class="heartIcon"></span>');
    heartIconWrapperDiv = $('<div class="heartIconWrapper heartIconWrapper-lightbox" style="position: relative"></div>');
    heartIconWrapperDivHover = $('<div class="heartIconWrapper heartIconWrapperWithHover" style="position: relative"></div>');

    initApi () {
        const that = this;

        window.likeHolder = {};
        window.likeHolder.stats = {};

        withPluginApi("0.8.38", (api) => {
            api.onPageChange(async (url, title) => {
                var res = url.match(/\/t\/(.*?)\/(\w+)/);

                this.topicId = res && res[2] > 0 ? res[2] : null;
                window.likeHolder.topicId = this.topicId || null;

                if (this.topicId) {
                    // make first run when all libs are loaded.
                    $(async function () {
                        that.likedMapping = await that.getLikesFromDatasource(that.topicId);
                        that.decorateInitialPosts();
                    })
                }
            })

            api.decorateCooked($elem => {
                setTimeout(function () {
                    // check if the post is already decorated
                    if ($($elem).attr('data-decorated')) return;
                    if (!$($elem).closest('article').length) return;

                    that.appendHeartIcon($elem);
                }, 1000)

            }, {id: 'add-hearts'})

            that.setupCookedImageHovers(api);
        });
    }

    // this runs when a new topic is loaded, it triggers the heart icon to be appended
    decorateInitialPosts() {
        const that = this;
        const $elems = $('.cooked');

        $elems.each(function (index, elem) {
            const $elem = $(elem);
            if (!$($elem).closest('article').length) return;

            that.appendHeartIcon($elem);
        });
    }

    // this loads likes on page change, per topic
    async getLikesFromDatasource(topicId) {
        return new Promise((resolve, reject) => {
            window.firebaseDb.collection(settings.firebase_firestore_database_collection).where("topicId", "==", parseInt(topicId))
                .get()
                .then((querySnapshot) => {
                    const arr = [];
                    querySnapshot.forEach((doc) => {
                        arr.push({id: doc.id, data: doc.data()});
                    });
                    resolve(arr);
                }).catch((error) => {
                console.log("Error getting document:", error);
                reject(error);
            });
        })
    }

    async appendHeartIcon($elem) {
        const that = this;
        $elem.attr('data-decorated', true);

        const topicPostId = $($elem).closest('article').attr('id').split('_')[1];
        // TODO: those could be cachaable
        const likes = this.likedMapping && this.likedMapping.filter((like) => like.data.topicPostId === parseInt(topicPostId));

        //console.log('Decorating post with hearts', topicPostId, likes);

        if (likes.length > 0) {
            //sync iterate over postTexts and add event listener to each text
            likes.forEach(({id, data: {text, mediaUrl, users, topicPostId, topicId, timestamp}}) => {

                // find li or p nodes that contain textObj.text or textObj.mediaUrl
                const likeType = text ? 'text' : 'media';
                let node = null;
                let hasHtmlEntities = false;
                const dbText = text;

                // find the node that contains the text
                if (likeType === 'text') {
                    //console.log('Node not found with text, trying html...')
                    text = this.replaceWithStrongTag(text);
                    text = this.replaceWithSTag(text);
                    text = this.replaceWithBRTagSimple(text);
                    text = this.replaceWithCodeTag(text);
                    text = this.replaceWithLiTag(text);
                    text = this.replaceLinkWithLinkHtml(text);
                    text = this.replaceMentionesWithHref(text);
                    text = this.replaceGroupMentionsWithHref(text);
                    text = this.restoreAmpersandCharacter(text);
                    text = this.replaceEmojiTextWithImgTag(text);
                    text = this.replaceAngleBrackets(text);


                    node = $elem.find('p').filter(function () {

                            //console.log('DB P ---------------:', text)
                            //console.log('P innerHtml.toString:', $(this)[0].innerHTML.trim().toString())
                            //console.log('P innerHtml---------:', $(this)[0].innerHTML.trim())
                            //console.log('P innerHtml removeEx:', removeExtraSpaces($(this)[0].innerHTML.trim()))
                            //console.log('P innerText --------:', $(this)[0].innerText)
                            //console.log('Extra includes -----:', removeExtraSpaces($(this)[0].innerHTML.trim().toString()).includes(text))

                        return that.removeExtraSpaces($(this)[0].innerHTML.trim().toString()).includes(text);
                    })[0] || $elem.find('li').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0] || $elem.find('div[data-timeline-parser-video-id]').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0]  || $elem.find('h1').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0] || $elem.find('h2').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0] || $elem.find('h3').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0] || $elem.find('h4').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0] || $elem.find('h5').filter(function () {
                        return $(this)[0].innerHTML.toString().includes(text);
                    })[0];

                    //console.warn("Node after trying to find it with html entities", node, text);

                    // if node not found, try to find it without html entities
                    if (!node) {
                        //console.error('Unable to find node with html entities, trying without...', text);
                        node = $elem.find('p').filter(function () {
                            //console.log(text, 'DB Text')
                            const innerTxt = this.innerText;
                            //console.log(this.innerText, 'Node Text')
                            //console.log(innerTxt.replace(/\n/g, ''), 'slash ne replaced node Text')
                            //console.log(innerTxt.replace(/\n/g, '').includes(text))
                            return this.innerText.includes(text);
                        })[0] || $elem.find('li').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('div[data-timeline-parser-video-id]').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('h1').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('h2').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('h3').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('h4').filter(function () {
                            return this.innerText.includes(text);
                        })[0] || $elem.find('h5').filter(function () {
                            return this.innerText.includes(text);
                        })[0];

                    }

                    // console.warn("Node after trying to find it with html entities", node);

                    if(!node) {
                        console.warn(`Problem with "Hearted" text that cant be found on page:`, {
                            id,
                            text,
                            mediaUrl,
                            users,
                            topicPostId,
                            topicId,
                            timestamp
                        }, `${settings.forum_url}/t/${topicId}/${topicPostId}`)
                        // console.error('converted text', text);
                        return;
                    }



                    let appendNode = null;
                    //console.log('node', node.innerText);
                    //console.log('stats', {id, data: {text, mediaUrl, users, topicPostId, topicId, timestamp}});

                    // this is required as the db text has only the @mention text but that needs to become html link


                    //console.log('text', text);
                    //console.log('node innerHtml', node.innerHTML);
                    //console.log('node innerText', node.innerText);

                    // Unstable. Rethink that
                    node.innerHTML = that.removeExtraSpaces(node.innerHTML).replace(text, `<span data-highlight="${users.length >= parseInt(settings.hearted_text_min_count_for_highlight)}" class="heart-markup-wrapper" id="${timestamp}" style="--color: ${settings.hearted_text_color}">${text}</span>`)
                    appendNode = $(node).find('#' + timestamp);

                    if (appendNode) {
                        const userHearted = users.includes(this.currentUser.id);
                        const heartIconClone = that.heartIcon.clone(true).hide();
                        heartIconClone.attr('data-count', users.length)
                            .attr('data-users', users.join(','))
                            .attr('data-id', id)
                            .attr('data-userHearted', userHearted)
                            .data('ttUpdated', false)
                            .data('ttLoaded', false);

                        $(appendNode).append(heartIconClone.fadeIn(1000));
                    }

                } else {
                    // find the node that contains the mediaUrl
                    node = $elem.find(`.lightbox > img[src *="${mediaUrl}"]`).parent().parent()[0];

                    if (node) {
                        //console.log('found node with mediaUrl lightnox')
                        const userHearted = users.includes(this.currentUser.id);
                        const heartIconClone = that.heartIcon.clone(true).hide();
                        heartIconClone.attr('data-count', users.length)
                            .attr('data-users', users.join(','))
                            .attr('data-id', id)
                            .attr('data-userHearted', userHearted)
                            .data('ttUpdated', false)
                            .data('ttLoaded', false);

                        $(node).append(heartIconClone.fadeIn(1000));
                    }

                    if (!node) {
                        node = $elem.find(`img[src *="${mediaUrl}"]`)[0];

                        if (node && !$(node).closest('.heartIconWrapper').length) {
                            //console.log('found node with mediaUrl without lightbox')
                            const userHearted = users.includes(this.currentUser.id);
                            const heartIconClone = that.heartIcon.clone(true).hide();
                            heartIconClone.attr('data-count', users.length)
                                .attr('data-users', users.join(','))
                                .attr('data-id', id)
                                .attr('data-userHearted', userHearted)
                                .data('ttUpdated', false)
                                .data('ttLoaded', false);
                            $(node).wrap(that.heartIconWrapperDiv);
                            $(node).parent().append(heartIconClone.fadeIn(1000));
                        }
                    }


                    // here we are decorating links that are used by the video-uploader plugin to construct a video thumbnail.
                    // we provide all nessesary initial info so that the heart can be drawn on the thumbnail
                    if (!node) {
                        node = $elem.find(`a[href *="${mediaUrl}"]`);

                        if (node) {
                            const userHearted = users.includes(this.currentUser.id);
                            node.attr('data-count', users.length)
                                .attr('data-users', users.join(','))
                                .attr('data-id', id)
                                .attr('data-userHearted', userHearted)
                                .data('ttUpdated', false)
                                .data('ttLoaded', false);
                        }
                    }


                }
            })
        }
    }


    onHeartButtonClickedPrep() {
        this._heartQuotePrep();
    }

    onHeartButtonClicked() {
        this._heartQuote();
    }

    async _heartQuote(newHeartProps) {
        // reroute to the other function as its used in other places
        console.log('_heartQuote newHeartProps', newHeartProps)
        return this._heartQuoteNonAction(newHeartProps);
    }

    // this method is a precursor to the actual hearting functionality
    // it checks where text is selected and check if a heart existed before at that location
    // it will prepare the data for the hearting functionality
    @bind
    async _heartQuotePrep() {
        const selection = window.getSelection();
        let commonAncestor = selection.getRangeAt(0).commonAncestorContainer;

        while (commonAncestor.nodeType !== Node.ELEMENT_NODE) {
            commonAncestor = commonAncestor.parentNode;
        }

        let sel = selection;
        let selRange = sel.getRangeAt(0);
        let node = selRange.startContainer;
        let counter = 0;

        var match = /\r|\n/.exec(selection);

        const myrange = document.createRange();
        myrange.selectNodeContents(commonAncestor);
        selection.removeAllRanges();
        selection.addRange(myrange);

        while (node !== selRange.endContainer) {
            if (node.nodeType === Node.ELEMENT_NODE) {
                counter++;
            }
            if (node.firstChild) {
                node = node.firstChild;
            } else if (node.nextSibling) {
                node = node.nextSibling;
            } else {
                while (node && !node.nextSibling) {
                    node = node.parentNode;
                }
                if (node) {
                    node = node.nextSibling;
                }
            }
        }
        if (node && node.nodeType === Node.ELEMENT_NODE) {
            counter++;
        }

        const topicController = getOwner(this).lookup("controller:topic");
        console.log(topicController.model, 'topicController model');

        const postId = topicController.quoteState?.postId;
        const postModel = topicController.model.postStream.findLoadedPost(postId);
        console.log(postId, 'postId')
        console.log(postModel, 'postModel')

        const $likeNode = $(commonAncestor).find('.heartIcon');
        const count = $($likeNode).attr('data-count') || 0;
        const users = $($likeNode).attr('data-users');
        const id = $($likeNode).attr('data-id') || null;

        const newLikeProps =
            {
                count: count ? parseInt(count) : 0,
                users: users !== undefined ? users.split(",").map(Number) : [],
                topicId: parseInt(postModel.topic_id),
                topicPostId: parseInt(postModel.post_number),
                userId: this.currentUser.id,
                timestamp: Date.now(),
                text: selectedText(),
                mediaUrl: null,
                id: id,
                commonAncestor: commonAncestor
            }

        //console.log('_heartQuotePrep newLikeProps', newLikeProps)

        this._heartQuoteNonAction(newLikeProps);
    }

    toggleLikeButton(commonAncestor) {
        const $toggleLikeButton = $(commonAncestor).parents('article:first').find('.widget-button.toggle-like');
        if (!$toggleLikeButton.hasClass('has-like')) {
            $toggleLikeButton.trigger('click');
            //$toggleLikeButton.trigger('focus');
            //console.log("triggering like button");
        }
    }

    async _heartQuoteNonAction(newHeartProps) {
        const heartIcon = $('<span class="heartIcon"></span>');

        let {
            count,
            users,
            topicId,
            topicPostId,
            userId,
            timestamp,
            id,
            text,
            mediaUrl,
            commonAncestor
        } = newHeartProps ? newHeartProps : window.likeHolder.stats;


        //console.log(newHeartProps ? newHeartProps : window.likeHolder.stats)

        if (count === 0) {
            console.log("First interaction. Adding heart...");

            const newEntryConfig = {
                text: text,
                mediaUrl,
                count: 1,
                users: [userId],
                topicId: parseInt(topicId),
                topicPostId: parseInt(topicPostId),
                userId: parseInt(userId),
                timestamp: Date.now(),
                id: Date.now()
            }

            // console.log(newEntryConfig, 'newEntryConfig');

            const newDocId = await this._setNewTopicPostLike(newEntryConfig);
            let appendNode = null;
            let node = null;
            if (text) {
                text = this.replaceWithStrongTag(text);
                text = this.replaceWithSTag(text);
                text = this.replaceWithBRTagSimple(text);
                text = this.replaceWithCodeTag(text);
                text = this.replaceWithLiTag(text);
                text = this.replaceLinkWithLinkHtml(text);
                text = this.replaceEmojiTextWithImgTag(text);
                text = this.replaceMentionesWithHref(text);
                text = this.restoreAmpersandCharacter(text);

                //console.log(text, 'text');
                //console.log(this.removeExtraSpaces(commonAncestor.innerHTML), 'commonAncestor.innerHTML');

                commonAncestor.innerHTML = this.removeExtraSpaces(commonAncestor.innerHTML).replace(text, `<span data-highlight="${newEntryConfig.count >= parseInt(settings.hearted_text_min_count_for_highlight)}" class="heart-markup-wrapper" id="${newEntryConfig.timestamp}" style="--color: ${settings.hearted_text_color}">${text}</span>`);

                /*
                        let innerHTML = commonAncestor.innerHTML;
                        innerHTML = this.replaceWithStrongTag(innerHTML);
                        innerHTML = this.replaceWithSTag(innerHTML);
                        innerHTML = this.replaceWithBRTag(innerHTML);
                        innerHTML = this.replaceWithCodeTag(innerHTML);
                        commonAncestor.innerHTML = innerHTML;
                        */

                appendNode = $(commonAncestor).find('#' + newEntryConfig.timestamp);
            } else {
                appendNode = $(commonAncestor).find('.heartIconWrapper');
                $(commonAncestor).find('.heartIconHover').remove();

                if (!appendNode.length > 0) {
                    appendNode = commonAncestor;
                }
            }

            if (appendNode) {
                const clonedHeartIcon = this.heartIcon.clone(true);
                clonedHeartIcon.attr('data-count', newEntryConfig.count);
                clonedHeartIcon.attr('data-users', newEntryConfig.users.join(','));
                clonedHeartIcon.attr('data-id', newDocId);
                clonedHeartIcon.attr('data-userHearted', true);
                clonedHeartIcon.data('ttLoaded', false);
                clonedHeartIcon.data('ttUpdated', false);

                $(appendNode).append(clonedHeartIcon).fadeIn(1000);

                window.likeHolder.stats = null;
                this.toggleLikeButton(commonAncestor);
            }

        } else {
            // User has already liked this post
            if (users.indexOf(this.currentUser.id) !== -1) {
                console.info("User already liked this text.");
                const newUsersWithoutCurrent = users.filter((id) => id !== userId);
                const newCount = newUsersWithoutCurrent.length;

                // user was sole liker, remove the whole wrap
                if (newUsersWithoutCurrent.length === 0) {
                    //console.log("User was the only heart... removing heart.");

                    // remove entry from likedMapping by id
                    const topicPostLikes = await this._getTopicPostLikes(topicId, topicPostId);
                    console.log(topicPostLikes, 'topicPostLikes');
                    const previoulyLikedEntry = topicPostLikes.find((entry) => entry.docId === id);
                    await this._deleteTopicPostLikes(previoulyLikedEntry.docId);

                    setTimeout(() => {
                        /*const $heartWrapperNode = $(commonAncestor).find('.heartIconWrapper');
                        $heartWrapperNode.replaceWith($heartWrapperNode[0].innerHTML);*/

                        //console.log(commonAncestor);
                        const $heartNode = $(commonAncestor).find('.heartIcon');
                        const hasImage = $(commonAncestor).find('img').length > 0;

                        if ($(commonAncestor).hasClass('heartIconWrapper')) {
                            $(commonAncestor).find('.heartIcon').remove();
                            $(commonAncestor).find('img:first').unwrap();
                        }

                        if ($(commonAncestor).hasClass('video-thumb-wrapper')) {
                            $(commonAncestor).find('.heartIcon').remove();
                        }

                        if ($(commonAncestor).hasClass('lightbox-wrapper')) {
                            $(commonAncestor).find('.heartIcon').remove();
                        }

                        // Unwrap text nodes.
                        if ($(commonAncestor).hasClass('heart-markup-wrapper')) {
                            $heartNode.remove();
                            $(commonAncestor).contents().unwrap();
                        }

                        window.likeHolder.stats = null;
                    }, 200);

                } else {
                    // user was not sole liker, remove him from the list
                    console.log("Many hearted... removing 1 heart.");
                    const newUsersWithoutCurrent = users.filter((id) => id !== userId);
                    const newCount = newUsersWithoutCurrent.length;

                    const topicPostLikes = await this._getTopicPostLikes(topicId, topicPostId);
                    const previoulyLikedEntry = topicPostLikes.find((entry) => entry.docId === id);

                    const updates = {
                        count: newCount,
                        users: newUsersWithoutCurrent
                    }

                    this._updateTopicPostLikes(previoulyLikedEntry.docId, updates);

                    setTimeout(() => {
                        const clonedHeartIcon = $(commonAncestor).find('.heartIcon');
                        clonedHeartIcon.attr('data-count', newCount);
                        clonedHeartIcon.attr('data-users', newUsersWithoutCurrent.join(','));
                        clonedHeartIcon.attr('data-id', previoulyLikedEntry.docId);
                        clonedHeartIcon.attr('data-userHearted', false);
                        clonedHeartIcon.data('ttLoaded', false);
                        clonedHeartIcon.data('ttUpdated', true);

                        window.likeHolder.stats = null;
                    }, 200);
                }

            } else {
                console.log("User did not like before but others did");
                const newUsers = [...users, this.currentUser.id];
                const newCountWithUser = newUsers.length;

                const topicPostLikes = await this._getTopicPostLikes(topicId, topicPostId);
                const previoulyLikedEntry = topicPostLikes.find((entry) => entry.docId === id);

                const updates = {
                    count: newCountWithUser,
                    users: newUsers
                }

                this._updateTopicPostLikes(previoulyLikedEntry.docId, updates);

                setTimeout(() => {
                    const clonedHeartIcon = $(commonAncestor).find('.heartIcon');
                    clonedHeartIcon.attr('data-count', newCountWithUser);
                    clonedHeartIcon.attr('data-users', newUsers.join(','));
                    clonedHeartIcon.attr('data-id', previoulyLikedEntry.docId);
                    clonedHeartIcon.attr('data-userHearted', true);
                    clonedHeartIcon.data('ttLoaded', false);
                    clonedHeartIcon.data('ttUpdated', true);

                    window.likeHolder.stats = null;

                    // trigger like button
                    this.toggleLikeButton(commonAncestor);
                }, 200);
            }
        }
    }

    extractStringFromUrl(url) {
        const urlParts = url.split('/');
        return urlParts[urlParts.length - 2];
    }

    // this method will handle a click event from a heart and then either remembers the selection text node or the image's url, to be saved later in the db
    handleHeartClick(e, context) {

        console.log('heart button trigger handleHeartClick', e.target);

        e.preventDefault();
        e.stopPropagation();

        const likeNode = e.target;
        const parent = $(likeNode)[0].parentNode;

        const topicPostId = $(likeNode).closest('article').attr('id').split('_')[1];
        const topicId = $(likeNode).closest('article').attr('data-topic-id');
        const count = $(likeNode).attr('data-count');
        const users = $(likeNode).attr('data-users');
        const id = $(likeNode).attr('data-id');

        if (parent.nodeName === 'A') {
            parent.preventDefault();
            parent.stopPropagation();
        }

        // video thumbnails are handled here
        if ($(likeNode).parents('.apollo-video-anchor').length > 0) {
            console.log('Clicked heart on video thumbnail.')
            const filename = this.extractStringFromUrl($(parent).closest('.apollo-video-anchor').attr('data-href'));
            //console.log('filename', filename);
            try {
                window.likeHolder.stats = {
                    count: count ? parseInt(count) : 0,
                    users: users !== undefined ? users.split(",").map(Number) : [],
                    topicId: parseInt(topicId),
                    topicPostId: parseInt(topicPostId),
                    userId: context.currentUser.id,
                    text: null,
                    mediaUrl: filename,
                    id,
                    commonAncestor: parent
                }
            } catch (e) {
                console.log(e);
            }

            if (!window.likeHolder.stats.hasOwnProperty('topicPostId')) return;

            setTimeout(() => {
                document.querySelector("#heart-button-trigger").click();
            }, 100);
            // non lightbox images are handled here
        } else if (parent.classList.contains('heartIconWrapper')) {
            const filename = parent.querySelector('img').src.split('/').pop();
            console.info('Clicked heart on inline image.')

            try {
                window.likeHolder.stats = {
                    count: count ? parseInt(count) : 0,
                    users: users !== undefined ? users.split(",").map(Number) : [],
                    topicId: parseInt(topicId),
                    topicPostId: parseInt(topicPostId),
                    userId: context.currentUser.id,
                    text: null,
                    mediaUrl: filename,
                    id,
                    commonAncestor: parent
                }
            } catch (e) {
                console.log(e);
            }

            if (!window.likeHolder.stats.hasOwnProperty('topicPostId')) return;

            //$(parent.querySelector('img')).removeClass('hovering').unwrap();
            $(likeNode).remove();

            setTimeout(() => {
                document.querySelector("#heart-button-trigger").click();
            }, 100);
            // lightbox images are handled here
        } else if (parent.classList.contains('lightbox-wrapper')) {
            const filename = parent.querySelector('.lightbox').href.split('/').pop();
            console.info('Clicked heart on lightbox image.')

            try {
                window.likeHolder.stats = {
                    count: count ? parseInt(count) : 0,
                    users: users !== undefined ? users.split(",").map(Number) : [],
                    topicId: parseInt(topicId),
                    topicPostId: parseInt(topicPostId),
                    userId: context.currentUser.id,
                    text: null,
                    mediaUrl: filename,
                    id,
                    commonAncestor: parent
                }
            } catch (e) {
                console.log(e);
            }

            if (!window.likeHolder.stats.hasOwnProperty('topicPostId')) return;

            setTimeout(() => {
                document.querySelector("#heart-button-trigger").click();
            }, 100);
        } else {

            console.log('Clicked heart on text.')

            const range = document.createRange();
            range.selectNodeContents(parent);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);

            // select comonancenstor from the selection
            const commonAncestor = selection.getRangeAt(0).commonAncestorContainer;

            try {
                window.likeHolder.stats = {
                    count: count ? parseInt(count) : 0,
                    users: users !== undefined ? users.split(",").map(Number) : [],
                    topicId: parseInt(topicId),
                    topicPostId: parseInt(topicPostId),
                    userId: context.currentUser.id,
                    text: selection.toString(),
                    mediaUrl: null,
                    id: id,
                    commonAncestor
                }
            } catch (e) {
                console.log(e);
            }

            console.log(window.likeHolder.stats, 'window.likeHolder.stats');

            setTimeout(() => {
                document.querySelector("#heart-button-trigger").click();
                setTimeout(() => {
                    selection.removeAllRanges();
                }, 1000);
            }, 100);
        }
    }

    // This will allow hearting images. You hover over an image and a heart will appear. When you click the heart, the image will be hearted.
    setupCookedImageHovers(api) {
        const hoverDelay = 0;
        const hoverOutDelay = 0;
        const that = this;

        api.decorateCooked($elem => {
            setTimeout(function () {
                const postArticleNode = $($elem).closest('article');

                // if no article node, skip
                if (!postArticleNode.length) return;

                const ariaLabel = postArticleNode[0].getAttribute('aria-label');

                // check if user can like his own content
                if (settings.allow_like_own_content === false && ariaLabel.includes(user.username)) {
                    return;
                }

                const nodes = $elem.find('img:not([src*="emoji"]');

                if (nodes.length) {
                    // exclude lis that have a p as child node from filteredNodes
                    const filteredNodes = nodes.filter((i, node) => {
                        return !$(node).find('p').length > 0 && !$(node).parents('.onebox-body').length && !$(node).parents('.embedded-posts').length && !$(node).parents('aside').length;
                    })

                    filteredNodes.each((i, domNode) => {
                        let hoverTimer;
                        let hoverOutTimer;
                        const isLightBoxImage = $(domNode).parents('.lightbox-wrapper').length > 0;

                        const parentNodeSelector = isLightBoxImage ? '.lightbox-wrapper:first' : ".heartIconWrapper:first";
                        const domNodeSelector = isLightBoxImage ? $(domNode).parents('.lightbox-wrapper') : $(domNode).parent();

                        domNodeSelector.hover(function () {
                            $(domNode).addClass('hovering');
                            clearTimeout(hoverOutTimer);
                            hoverTimer = setTimeout(() => {
                                if (!$(domNodeSelector).find('.heartIcon').length > 0) {
                                    const myWrapperDiv = that.heartIconWrapperDivHover.clone(true);
                                    if (!isLightBoxImage) {
                                        myWrapperDiv.on('mouseenter', function () {
                                            clearTimeout(hoverOutTimer);
                                        });
                                    }

                                    if (isLightBoxImage) {
                                        if ($(domNode).parents('.heartIconWrapper').length > 0) {
                                            $(domNode).parents('.heartIconWrapper').append(that.heartIcon.clone(true).addClass('heartIconHover').hide().fadeIn({duration: 150}));
                                        } else {
                                            $(domNode).parent().wrap(myWrapperDiv);
                                            $(domNode).parents('.heartIconWrapper').append(that.heartIcon.clone(true).addClass('heartIconHover').hide().fadeIn({duration: 150}));
                                        }

                                    } else {
                                        if ($(domNode).parents('.heartIconWrapper').length > 0) {
                                            $(domNode).parents('.heartIconWrapper').append(that.heartIcon.clone(true).addClass('heartIconHover').hide().fadeIn({duration: 150}));
                                        } else {
                                            $(domNode).wrap(myWrapperDiv);
                                            $(domNode).parents(parentNodeSelector).append(that.heartIcon.clone(true).addClass('heartIconHover').hide().fadeIn({duration: 150}));
                                        }
                                    }

                                }
                            }, hoverDelay);

                        }, function () {
                            $(domNode).removeClass('hovering');
                            clearTimeout(hoverTimer);
                            hoverOutTimer = setTimeout(() => {
                                if ($(domNode).parents('.heartIconWrapper').length > 0) {
                                    if (isLightBoxImage) {
                                        $(domNode).parents('.heartIconWrapper').find('.heartIconHover').fadeOut({
                                            duration: 150, done: function () {
                                                $(domNode).parents('.lightbox').unwrap()
                                                $(this).remove()
                                            }
                                        });
                                    } else {
                                        $(domNode).parents('.heartIconWrapper').find('.heartIconHover').fadeOut({
                                            duration: 150, done: function () {
                                                // check if a registered heart was appended to the wrapper, if not the unwrap
                                                if (!$(domNode).parents('.heartIconWrapper:first').find('.heartIcon[data-count]').length > 0) {
                                                    $(domNode).unwrap()
                                                }
                                                $(this).remove()
                                            }
                                        });
                                    }


                                }
                            }, hoverOutDelay);

                        });
                    });
                }
            }, 100)
        }, {id: 'add-hovers', afterAdopt: true});
    }

    hoverEventHeart(e) {
        //console.log('hoverEventHeart', e);
        if ($('html').hasClass('mobile-view')) {
            return;
        }

        const that = $(this);
        if ($(that).data('ttLoaded') === true) return;
        const usersIds = $(that).attr('data-users');

        const promise = ajax("/user-cards.json", {
            data: {user_ids: usersIds}
        });
        promise.then((result) => {
            $(that).data('ttLoaded', true);

            const userCards = result.users;
            const userCardsHtml = userCards.map((userCard) => {
                return `<span>${userCard.name}</span>`;
            }).join('');

            // save the tooltip in the dom
            if (that.data('tippy') && that.data('ttUpdated') === false) {
                that.data('tippy').show();
            } else {

                const instance = tippy(this, {
                    content: `<div class="tooltip-likers"><em>People who liked this:</em> <br />${userCardsHtml}</div>`,
                    allowHTML: true,
                    placement: 'bottom',
                    showOnCreate: true,
                    onShow() {
                        $(that).parent().addClass('quote-previewed');
                    },
                    onHide() {
                        $(that).parent().removeClass('quote-previewed');
                    }
                });
                if (that.data('tippy')) {
                    that.data('tippy').destroy();
                }

                that.data('tippy', instance);
                that.data('ttUpdated', false);
            }
        });
    }

    hoverVideoThumbs(e, context) {
        const hoverDelay = 0;
        const hoverOutDelay = 0;

        const videoWrapperNode = $(e.currentTarget);
        const postArticleNode = $(videoWrapperNode).closest('article');
        const ariaLabel = postArticleNode[0].getAttribute('aria-label');

        // check if user can like his own content
        if (settings.allow_like_own_content === false && ariaLabel.includes(user.username)) {
            return;
        }

        let hoverOutTimer;

        $(videoWrapperNode).addClass('hovering');  // add class to parent
        clearTimeout(hoverOutTimer);
        let hoverTimer = setTimeout(() => {
            //console.log('hovering video');
            if (!$(videoWrapperNode).find('.heartIcon').length > 0) {
                $(videoWrapperNode).append(context.heartIcon.clone(true).addClass('heartIconHover').hide().fadeIn({duration: 150}))
            }
        }, hoverDelay);

        videoWrapperNode.unbind().on('mouseleave', function () {
            $(videoWrapperNode).removeClass('hovering');
            clearTimeout(hoverTimer);
            hoverOutTimer = setTimeout(() => {
                if ($(videoWrapperNode).find('.heartIconHover').length > 0) {
                    $(videoWrapperNode).find('.heartIconHover').fadeOut(150, function () {
                        $(this).remove();
                    })
                }
            }, hoverOutDelay);
        });
    }

    async _getTopicPostLikes(topicId, topicPostId) {
        return new Promise((resolve, reject) => {
            window.firebaseDb.collection(settings.firebase_firestore_database_collection).where("topicId", "==", topicId).where("topicPostId", "==", topicPostId).get().then((querySnapshot) => {
                const likes = [];
                querySnapshot.forEach((doc) => {
                    likes.push({docId: doc.id, ...doc.data()});
                });
                resolve(likes);
            }).catch((error) => {
                console.log("Error getting document:", error);
                reject(error);
            });
        })
    }

    async _setNewTopicPostLike(likeData) {
        return new Promise((resolve, reject) => {
            window.firebaseDb.collection(settings.firebase_firestore_database_collection).add(likeData).then((data) => {
                //console.log("New Like written!", data.id)
                resolve(data.id);
            }).catch((error) => {
                console.error("Error writing document: ", error);
                reject(false);
            });
        })
    }

    async _deleteTopicPostLikes(docId) {
        return new Promise((resolve, reject) => {
            window.firebaseDb.collection(settings.firebase_firestore_database_collection).doc(docId).delete().then(() => {
                //console.log("Like entry successfully deleted!");
                resolve(true);
            }).catch((error) => {
                console.error("Error removing Like: ", error);
                reject(false);
            });

        })
    }
    async _updateTopicPostLikes(docId, updates) {
        return new Promise((resolve, reject) => {
            var washingtonRef = window.firebaseDb.collection(settings.firebase_firestore_database_collection).doc(docId);
            return washingtonRef.update(updates)
                .then(() => {
                    //console.log("Like successfully updated!", docId, updates);
                    resolve(true);
                })
                .catch((error) => {
                    console.error("Error updating document: ", error);
                    reject(true);
                });
        })
    }

     removeExtraSpaces(text) {
        return text.replace(/\s+/g, ' ');
    }

    replaceWithStrongTag(text) {
        if (typeof text === 'string') {
            return text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
        }
        return text;
    }

    replaceWithSTag(text) {
        return text.replace(/\~\~(.*?)\~\~/g, '<s>$1</s>');
    }
    replaceWithCodeTag(text) {
        return text.replace(/`(.*?)`/g, '<code>$1</code>');
    }

    replaceWithLiTag(text) {
        return text.replace(/\* (.*?)/g, '<li>$1</li>');
    }

    restoreAmpersandCharacter(text) {
        return text.replace(/&/g, '&amp;');
    }

    replaceEmojiTextWithImgTag(text) {
        return text.replace(/:(\w+):/g, function(match, emoji) {
            return `<img src="https://emoji.discourse-cdn.com/twitter/${emoji}.png?v=12" title=":${emoji}:" class="emoji" alt=":${emoji}:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;">`;
        });
    }

    replaceAngleBrackets(text) {
        return text.replace(/<-/g, '&lt;-').replace(/->/g, '-&gt;');
    }

    replaceGroupMentionsWithHref(text) {
        const groups = ["Story", "3D_Art", "Animation", "Art", "Audio", "Cinematic_Animators", "Community_Management", "Design", "Finance", "Gameplay_Animators", "kws_qa", "Leads", "Level_Design", "Production", "QA", "Tech", "Tech_Leads"]; // Add your groups here
        const groupRegex = new RegExp(`@(${groups.join('|')})`, 'g');
        return text.replace(groupRegex, function(match, group) {
            return `<a class="mention-group notify" href="/groups/${group.toLowerCase()}">@${group}</a>`;
        });
    }

    replaceMentionesWithHref(text) {
        const nonGroupRegex = new RegExp(`@(\\w+)`, 'g');
        return text.replace(nonGroupRegex, function(match, username) {
            if (groups.includes(username)) {
                return match; // If it's a group, don't replace it
            }
            return `<a class="mention" href="/u/${username.toLowerCase()}">@${username}</a>`;
        });
    }

    replaceLinkWithLinkHtml(text) {
        return text.replace(/\[(.*?)\]\((.*?)\)/g, function(match, text, url) {
            return `<a href="${url}">${text}</a>`;
        });
    }

    removeExtraSpaces(text) {
        return text.replace(/\s+/g, ' ');
    }

    replaceWithBRTagSimple(text) {
        return text.replace(/\r|\n/g, '<br> ');
    }

    replaceWithBRTag(text) {
        var match = /\r|\n/.exec(text);
        var highlightedTexts = text;
        var adjustedSelection = text;
        var occurrence = 0;
        var regexp = /\r|\n/g;
        while (match = regexp.exec(highlightedTexts)) {
            // match is an object which contains info such as the index at which the matched keyword is present
            //console.log(match);
            //Output the matched keyword which is new line character here.
            //console.log("Keyword: ", match[0]);
            //Index at which the matched keyword is present.
            //console.log("Index: ", match.index);

            let index = match.index;
            let charsToAdd = "<br>";

            adjustedSelection = [adjustedSelection.slice(0, index), charsToAdd, adjustedSelection.slice(index)].join('');
            occurrence++;
        }

        return adjustedSelection.trim();
    }
}