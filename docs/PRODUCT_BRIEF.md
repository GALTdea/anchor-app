# Product Brief

This document captures the product north star for Anchor. Keep it short,
stable, and useful for AI-assisted development. Feature-level details belong in
`docs/features/`.

---

## Product Goal

Anchor is an AI-supported parent companion for autism care that helps
caregivers build a clearer, more actionable understanding of their child over
time. Its core purpose is to turn scattered parent observations, onboarding
answers, and daily experiences into a living child profile that helps families
better understand behavior, notice patterns, and make more confident support
decisions.

At the product level, Anchor is designed to reduce parent uncertainty. Instead
of expecting caregivers to interpret behaviors alone, Anchor helps them answer a
simpler question: "What is likely going on with my child, and what should I do
next?" The app does this by collecting structured inputs, synthesizing them into
a child profile, and translating that profile into practical guidance,
recommendations, and next steps.

Anchor is not a diagnostic tool. Its outputs should be framed as
support-oriented guidance and working hypotheses for caregivers, not clinical
determinations.

---

## Target User

Anchor's primary target user is a parent or primary caregiver of a child with
autism who wants more clarity, more practical support, and a better
understanding of their child's behavior and development. The MVP is
intentionally parent-first: it is designed for the adult who is with the child
every day and needs support interpreting behaviors, responding more effectively,
and building confidence at home.

This parent may be early in their autism journey, between appointments,
overwhelmed by conflicting information, or looking for a calmer way to make
sense of everyday behaviors.

The initial product is not built for clinics, providers, or institutions.
Therapists, teachers, and external collaborators are important future users, but
they are secondary in the MVP. In the first version, Anchor is optimized for the
parent who is trying to understand their child better, make sense of difficult
moments, and receive useful next steps without needing clinical expertise.

---

## MVP Promise

Anchor's MVP promise is simple: help a parent build a clearer picture of their
child and leave them with useful, personalized next steps after just one guided
onboarding experience.

In the MVP, Anchor does not try to be a full therapy platform, provider portal,
or care management system. Its promise is narrower and more immediate: a parent
can answer a guided onboarding assessment, receive an initial child profile,
understand a few likely patterns behind what they are seeing, and walk away with
recommendations that feel specific and useful.

The MVP delivers immediate value by helping parents:

- understand their child a little better
- feel less uncertain about what they are seeing
- see a few likely patterns behind behaviors or needs
- receive personalized recommendations
- begin building a longer-term profile that improves over time

The MVP should not require the parent to understand internal app concepts like
workspaces, assessments, evidence, snapshots, or recommendations before
receiving value.

---

## Core User Journey

The core MVP journey is a child-first onboarding flow that helps a parent move
from uncertainty to initial clarity in one guided experience.

The journey is:

1. Parent lands on the app and clicks "Start your child's profile."
2. Parent enters a few basic child details.
3. Parent completes a guided onboarding assessment.
4. Anchor creates the child's first profile behind the scenes.
5. Parent receives an initial results experience, which may include:
   - an initial profile summary
   - an explanation of likely patterns
   - a first set of recommendations or next steps
6. Parent continues using the app to refine that profile over time through
   future assessments and, post-MVP, observations.

The exact contents and presentation of the first results experience should be
defined in a dedicated feature brief before implementation.
