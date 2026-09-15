# Minukuru repository review policy

Review the exact base-to-head diff as an iOS application and content-delivery system.

Prioritize:

- SwiftUI, StoreKit, accessibility, and iPhone/iPad behavioral regressions
- premium entitlement checks and accidental free access to premium content
- Supabase RLS, `security definer`, Edge Function authentication, authorization, and CORS boundaries
- exposure of API keys, service-role credentials, unreleased questions, correct answers, or private source material
- stale or mismatched human-review decisions entering a manifest
- content-safety regressions affecting children, older adults, or misinformation-literacy training
- missing focused tests for changed behavior

Do not treat external account setup, deployment, pricing, review approval, or production observation as a code finding. Report those as manual checks.
