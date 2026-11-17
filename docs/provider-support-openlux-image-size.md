# OpenLux: GPT Image 2 ignores requested pixel size

Status: NOT SENT. A confirmed support channel for this account is not configured in this environment. This text is ready for the owner to forward. No API key, private client source or personal Telegram ID is included.

Hello. Please check a synchronous image generation through your GPT Image 2 route.

- Endpoint: POST https://api.openlux.ai/v1/images/generations
- Exact model: gpt-image-2
- Parameters: n=1, size=1024x1024; a neutral prompt describing one orange wooden toy cube on a white background.
- Expected: one 1024×1024 image. Your [GPT Image 2 example](https://doc.openlux.ai/tutorials/python-5459039) supplies this exact model and size.
- Observed: HTTP response returned an image; the downloaded original PNG is 1254×1254, 1,592,985 bytes.
- Original SHA-256: 8720294d2190609e97e19302118df8e391a4dfcaf057ae98604d26ac0873106a.
- There was no explicit API error. Provider request/task ID was not retained in the sanitized audit; the caller's private log can correlate the request time. No retry was made.
- The original PNG is preserved unmodified. Locally resizing it would not verify the provider contract.

Please confirm which parameters or account group are required to honor exact pixel dimensions for this precise model, and whether the returned image reflects an upstream resize or an ignored parameter. We will run a fresh bounded live check after your answer and a permitted budget window.

