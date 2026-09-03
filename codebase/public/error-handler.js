// Location: public/error-handler.js (COMPLETE CODE)
(function() {
    // --- Configuration: Get Parent Origin ---
    // This global variable (e.g., "http://vps.ip:8000") MUST be injected into the
    // index.html by VITE backend *before* this script runs.
    //TODO: Fallback to '*' IS NOT RECOMMENDED for production due to security risks.
    const PARENT_ORIGIN = window.PARENT_ORIGIN || '*';
    if (PARENT_ORIGIN === '*') {
        console.warn('[Handler] PARENT_ORIGIN global variable not set! Using wildcard "*" for postMessage. This is insecure and should be fixed by backend injection.');
    } else {
        console.log('[Handler] Using parent origin for postMessage:', PARENT_ORIGIN);
    }

    // --- Helper: Debounce identical errors ---
    let reportedErrorsCache = new Set();
    const DEBOUNCE_TIME = 3000; // Don't report the exact same error more than once every 3 seconds

    // --- Helper: Send Message to Parent ---
    function reportErrorToParent(errorDetails) {
        // Create a key to identify unique errors for debouncing
        const errorKey = `${errorDetails.errorType}|${errorDetails.message}|${errorDetails.lineno}|${errorDetails.colno}`;

        // Check if this exact error was reported recently
        if (reportedErrorsCache.has(errorKey)) {
            // console.log('[Handler] Debounced duplicate error:', errorKey);
            return;
        }
        // Add to cache and set timeout to clear it
        reportedErrorsCache.add(errorKey);
        setTimeout(() => reportedErrorsCache.delete(errorKey), DEBOUNCE_TIME);

        // Only send if running inside an iframe
        if (window.parent !== window) {
            try {
                // Send the error payload to the parent window, targeting the specific origin
                window.parent.postMessage(
                    {
                        type: 'iframeError', // Consistent message type identifier
                        payload: errorDetails, // The structured error data
                    },
                    PARENT_ORIGIN // Security: Only send to this specific origin
                );
                console.log('[Handler] Message posted to parent. Type:', errorDetails.errorType);
            } catch (e) {
                // Log errors occurring during the postMessage call itself
                console.error("[Handler] Failed to postMessage:", e);
            }
        } else {
            // Useful for debugging if the script runs outside an iframe
            // console.warn("[Handler] Not running inside an iframe, error not posted to parent.");
        }
    }

    // --- Runtime Error Handlers (window.onerror / window.onunhandledrejection) ---
    function setupRuntimeErrorHandlers() {
        // Handle synchronous errors and script loading errors
        window.onerror = function(message, source, lineno, colno, error) {
            console.log('[Handler] window.onerror caught:', message);
            reportErrorToParent({
                message: typeof message === 'string' ? message.replace(/^Uncaught /,'') : 'Runtime Error', // Clean "Uncaught " prefix
                source: source,
                lineno: lineno,
                colno: colno,
                stack: error?.stack || '', // Include stack trace if available
                errorType: 'runtime', // Classify as runtime error
            });
            // Return false to allow default browser error handling (optional)
            return false;
        };

        // Handle unhandled promise rejections (async errors)
        window.onunhandledrejection = function(event) {
            console.log('[Handler] window.onunhandledrejection caught:', event.reason);
            const error = event.reason;
            reportErrorToParent({
                message: error?.message || 'Unhandled promise rejection',
                stack: error?.stack || (typeof error === 'string' ? error : 'No stack available'), // Include stack or reason string
                errorType: 'runtime', // Classify as runtime error
                // Include raw reason if it wasn't a standard Error object
                rawReason: !(error instanceof Error) ? String(error) : undefined,
            });
            // Prevent default browser handling (optional)
            // event.preventDefault();
        };

        console.log('[Handler] Runtime error handlers attached successfully.');
    }

    // --- Vite Compilation Error Handler (MutationObserver) ---
    function watchForViteErrors() {
        console.log('[Handler] Initializing MutationObserver v5 (Shadow DOM check)...');
    
        // Create an observer instance to watch for DOM changes
        const observer = new MutationObserver((mutationsList) => {
            // This function gets called whenever observed mutations occur
            for (const mutation of mutationsList) {
                // We are interested in changes where nodes were added to the DOM
                if (mutation.type === 'childList') {
                    // Iterate over each node that was added
                    mutation.addedNodes.forEach(node => {
                        // We only care about HTML elements
                        if (!(node instanceof HTMLElement)) return;
    
                        // --- 1. IDENTIFY THE VITE ERROR OVERLAY ELEMENT ---
                        //    Check using the specific tag name Vite uses.
                        //    Also include fallback ID check just in case.
                        let isOverlayNode = false;
                        if (node.tagName === 'VITE-ERROR-OVERLAY') isOverlayNode = true;
                        if (!isOverlayNode && node.id === 'vite-error-overlay') isOverlayNode = true;
                        // Add other checks here if needed (e.g., checking classList)
    
                        // If the added node is the Vite overlay...
                        if (isOverlayNode) {
                            console.log('[Handler] Detected <vite-error-overlay> node.');
    
                            // --- 2. ACCESS SHADOW ROOT & EXTRACT ERROR DETAILS ---
                            let errorMessage = 'Vite Compilation Error (Extraction Failed V5)'; // Default error message
                            let errorStack = ''; // Placeholder for stack/context
                            let detailElement = null; // Variable to hold the found detail DOM element
    
                            // Check if the overlay element uses Shadow DOM
                            if (node.shadowRoot) {
                                console.log('[Handler] Shadow root found. Querying inside shadow root...');
                                // Query for the <pre> tag with class "message" INSIDE the shadow root
                                detailElement = node.shadowRoot.querySelector('pre.message');
    
                                if (detailElement) {
                                    console.log('[Handler] Found "pre.message" within shadow DOM.');
                                } else {
                                    console.error('[Handler] Could not find "pre.message" within shadow DOM! Trying broader "pre"...');
                                    // Fallback to any <pre> inside shadow DOM if specific one not found
                                    detailElement = node.shadowRoot.querySelector('pre');
                                    if (detailElement) console.log('[Handler] Used fallback "pre" selector within shadow DOM.');
                                }
                            } else {
                                // Fallback if no shadow root is found (less likely for <vite-error-overlay>)
                                console.warn('[Handler] No shadow root found on <vite-error-overlay>! Querying light DOM...');
                                detailElement = node.querySelector('pre.message') || node.querySelector('pre');
                                if (detailElement) console.log('[Handler] Found detail element in light DOM (unexpected).');
                            }
    
                            // --- Extract text content if the detail element was successfully found ---
                            if (detailElement) {
                                 const fullText = detailElement.textContent?.trim();
                                 if (fullText) {
                                    // Assign the full extracted text to both message and stack
                                    errorMessage = fullText;
                                    errorStack = fullText;
                                    console.log('[Handler] Extracted details successfully.');
                                } else {
                                    // Handle case where the element was found but had no text content
                                    console.warn('[Handler] Found detail element, but textContent was empty.');
                                    errorMessage = 'Vite Error Overlay Found (Empty Detail Element)';
                                }
                            } else {
                                 // Log error if no suitable element was found anywhere
                                 console.error('[Handler] Failed to find detail element in shadow DOM or light DOM.');
                            }
                            // --- END OF EXTRACTION LOGIC ---
    
                            console.log(`[Handler] Final Message: ${errorMessage.substring(0,150)}...`); // Log truncated message for confirmation
    
                            // --- 3. REPORT THE ERROR TO THE PARENT WINDOW ---
                            reportErrorToParent({
                                message: errorMessage, // The detailed error message
                                stack: errorStack,     // The same detailed context/message
                                errorType: 'viteCompilation', // Specific type for this error
                            });
    
                        } // End if (isOverlayNode)
                    }); // End forEach(node)
                } // End if (mutation.type === 'childList')
            } // End for (mutation)
        }); // End MutationObserver callback
    
        // --- Start Observing ---
        // Ensure document.body exists before starting the observer
        if (document.body) {
            observer.observe(document.body, {
                childList: true, // Watch for nodes being added or removed
                subtree: true    // Watch the entire DOM tree under the body
            });
            console.log('[Handler] MutationObserver watching document.body v5.');
        } else {
             // Log an error if the body isn't ready - shouldn't happen if called correctly
             console.error('[Handler] Cannot attach MutationObserver: document.body not found!');
        }
    }
    // --- Initialization Logic ---

    // Setup runtime handlers immediately
    setupRuntimeErrorHandlers();

    // Setup Vite error watcher when the DOM is ready
    if (document.readyState === 'interactive' || document.readyState === 'complete') {
        // If DOM is already loaded, start watching
        watchForViteErrors();
    } else {
        // Otherwise, wait for the DOMContentLoaded event
        document.addEventListener('DOMContentLoaded', watchForViteErrors, { once: true });
    }

})(); // Immediately Invoked Function Expression (IIFE)