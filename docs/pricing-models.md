# Pricing Models

This note summarizes the pricing models discussed for Voiced as a potential commercial Mac utility.

## Product Assumption

Voiced is positioned as a local-first Mac dictation utility for individuals, not an enterprise voice platform.

The core commercial wedge is:

- no account
- no cloud transcription
- no subscription
- no server-side inference cost
- no payment infrastructure outside the App Store
- private local dictation with a one-time unlock

Enterprise-oriented tools such as Wispr Flow and Superwhisper can justify subscription pricing through team features, cloud services, compliance, admin workflows, cross-platform sync, and ongoing infrastructure. Voiced should not try to match that shape unless the product deliberately moves into a different market later.

## Models Considered

### Free Only

Voiced could remain free.

Pros:

- simplest App Store review path
- easiest adoption
- no IAP implementation
- useful for validation and TestFlight

Cons:

- no direct commercial return
- weak incentive to maintain long term
- does not test willingness to pay

This is useful before App Store or external TestFlight approval, but not the intended commercial model.

### One-Time Lifetime Unlock

The preferred model is a free app with a one-time in-app purchase to unlock the full product.

Suggested structure:

- Free: Tiny model, local push-to-talk dictation, basic output
- Paid lifetime unlock: more accurate models, richer review/export workflows, future local features

Candidate prices:

| Price | Read |
| ---: | --- |
| GBP 4.99 | Likely too cheap; risks making the app feel disposable |
| GBP 9.99 | Strong introductory price and easy impulse purchase |
| GBP 14.99 | Best default price; affordable but still signals a serious utility |
| GBP 19.99 | Plausible later if polish, reviews, and model quality are strong |
| GBP 29.99+ | Possible for a mature product, but harder to justify early |

Preferred path:

1. Launch with an introductory lifetime unlock around GBP 9.99.
2. Move the standard lifetime price to GBP 14.99.
3. Consider GBP 19.99 only after the app has stronger proof: reviews, polish, reliable conversion, and clear differentiation.

Marketing angle:

> Free forever for basic local dictation. Pay once for better accuracy.

This model best matches Voiced's low operating cost and no-subscription philosophy.

### Annual Subscription

An annual model was considered, using products such as Day One as an analogy.

Pros:

- smoother recurring revenue
- better support for ongoing maintenance
- easier to fund long-term development

Cons:

- weakens the strongest positioning: no subscription
- harder to justify without cloud services, accounts, sync, storage, or ongoing server costs
- risks making Voiced feel like the products it is trying to contrast against

Conclusion: do not start with annual-only pricing. Annual pricing only makes sense later if Voiced adds features with real ongoing cost or recurring service value, such as cloud transcription fallback, sync, team workflows, hosted models, or AI features that depend on paid APIs.

### Hybrid Annual And Lifetime

Another possible model is offering both annual and lifetime options.

Example:

- GBP 9.99 per year
- GBP 24.99-39.99 lifetime

Pros:

- gives users choice
- creates some recurring revenue
- keeps a pay-once option available

Cons:

- more complex messaging
- more IAP complexity
- can blur the clean "pay once" promise

Conclusion: potentially useful later, but too complex for the initial commercial version.

### Paid Major Versions

Another non-subscription model is paid major upgrades.

Example:

- Voiced 1 lifetime unlock covers all Voiced 1.x features.
- Voiced 2 is a separate optional paid upgrade later.

Pros:

- preserves the traditional "buy software" model
- avoids subscriptions
- creates future upgrade revenue

Cons:

- harder to implement cleanly in the App Store
- requires enough major-version value to justify an upgrade
- less predictable than subscriptions

Conclusion: worth keeping in mind, but not required for the first commercial version.

## Free Tier Shape

The strongest free tier proposal is:

- Tiny model only
- local transcription
- push-to-talk recording
- basic clipboard output and transcript review
- generous or unlimited usage

Because Voiced has no server-side inference cost, usage limits are not required for cost control. The upgrade pressure should come from accuracy and workflow quality rather than artificial scarcity.

Possible free-tier approaches:

| Approach | Notes |
| --- | --- |
| Tiny model only, unlimited usage | Cleanest and most aligned with local-first positioning |
| Daily or monthly minute limit | Controls heavy free usage, but feels more SaaS-like |
| Transcription count limit | Easy to understand, but may feel arbitrary |
| Session length cap | Can protect against long-form use while preserving short dictation |

Preferred free tier:

> Tiny model only, with no hard usage limit unless conversion data shows a need.

## Paid Unlock Features

Paid value should be concrete and tied to the core loop.

Likely paid unlocks:

- Base, Small, and Large v3 transcription models
- more accurate transcription
- richer review, drag, and export workflows
- custom vocabulary, if implemented
- local transcript history, if implemented
- prompt/message/email cleanup modes, if implemented locally
- advanced model controls
- future local model improvements

Avoid adding features that change the business model unless there is a deliberate strategy shift:

- cloud sync
- user accounts
- team dashboards
- enterprise compliance promises
- remote transcription
- hosted model inference
- API-backed AI rewriting that creates ongoing cost

## Revenue Framing

At GBP 14.99, Apple Small Business Program economics imply approximate net revenue of GBP 12.74 per paid user before taxes, refunds, and other operating costs.

Illustrative lifetime revenue:

| Paid users | Gross revenue | Approx net after 15% App Store fee |
| ---: | ---: | ---: |
| 1,000 | GBP 14,990 | GBP 12,742 |
| 5,000 | GBP 74,950 | GBP 63,708 |
| 10,000 | GBP 149,900 | GBP 127,415 |
| 25,000 | GBP 374,750 | GBP 318,538 |
| 50,000 | GBP 749,500 | GBP 637,075 |

These are planning ranges, not forecasts. For a solo-founder side business, the relevant target is a long-tail trickle of thousands of paid users over one to three years, not a venture-scale outcome.

## Sequencing

Commercial implementation should wait until Apple gives a useful signal that the app shape is acceptable.

Recommended order:

1. Ship a simple free TestFlight build.
2. Get external TestFlight approval.
3. Use that approval as a signal that the permissions, local transcription, model downloads, and App Store posture are viable.
4. Add IAP only after the core app review risk has been reduced.
5. Then implement the free tier and lifetime unlock.

External TestFlight approval is not a guarantee of App Store approval, but it is a useful milestone before investing in commercial plumbing.

## Current Recommendation

Use a simple freemium lifetime model:

- Free: Tiny model, basic local dictation
- Lifetime unlock: GBP 14.99 standard price
- Optional launch price: GBP 9.99
- No subscription at launch
- No accounts, servers, sync, or cloud inference

The product should stay narrow:

> Keep the loop excellent. Sell the pricing philosophy clearly. Update models when they improve the experience.
