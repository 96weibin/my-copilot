# Clean Meeting Transcript (for learning)

Original: `d:\github\MyNotes\Agile\meeting record\项目进展与问题讨论.txt`

---

## Opening (~01:23)

**[K]** People are still coming in. Let's wait a few more seconds, then we'll start.

As I put a note in this meeting's chat yesterday — we will be going over the Iteration 2 reviews.

Iteration 2 is now complete. That means technically, since we planned for four iterations, we are about halfway through the PI. So let's look at the progress, as well as...

---

## First Agenda Item (~02:00)

**[K]** Are there stories that rolled over from Iteration 2 to Iteration 3?

If so, what is the impact **downwards** for the BI objectives for each team? And in general, the impact to the CP5 **milestones**?

**In addition to that**, we can also have a quick discussion on:
- How we're handling post-development bugs
- How this is impacting our workflow

We'll spend some time on that.

---

## Board Hygiene (~02:30)

**[K]** OK, before we go to individual teams — by the way, I put a note out for all ATLs: please clean up the Lucid board.

- If you have new risks identified, please add them
- Any user stories or dependencies on the Lucid board that need to be moved around — just do some cleanup

---

## Risk Discussion (~03:15)

**[K]** I moved some of these risks to ADO — they show up there.

However, some new risks were added last week. I believe we discussed this:
- Who owns it?
- Is it impacting anything?
- Can someone comment?
- Have we mitigated this?

I believe we're deferring FCC, right? That was the decision we took.

Edgar, can you comment on power?

**Someone:** Yeah, IT is on vacation to handle this alone, but yes.

**Someone else:** That is correct.

**[K]** OK, so I'll move it to resolved.

---

## Quality: Pass Rates (~04:02)

**[K]** OK — the new risk added last week was around:
- New features testing
- Feature-level pass rates based on bugs reported
- Concerns raised by our quality team

**[A to Shirley]** Shirley raised concerns about two products with relatively low feature pass rates — Aus and AuP.

Can you comment on this? How is it this week?

I saw a message from Judy earlier. Is it the same two products currently having issues? How is this impacting things in general?

Please comment, Shirley.

**[M]** Yeah, I think every team sent out the report. You can probably open the Aus report. Features with very low pass rate — there's more detail there. It's not the end.

Judy also summarized the current progress status, so we can look into that too. Report was sent by Hongyan today for the Aus side.

**[K]** Some of the items, some of the features even with a pass rate like 20% — that's quite low. So... is there a change in the way we're calculating these pass rates? Is it still based on the bugs reported? Is there a change? Can you please explain this to the team?

**[M]** For the new spell, we have training. There is a guide based on tips for severity. There's a mapping table we usually use for the pass/fail.

You're breaking up a bit, Sherry.

**[K]** OK — but there's no major change except for severity and how bugs are counted, right? No change in how we calculate pass/fail rates?

**[M]** No.

**[K]** OK, these are all the bugs reported.

---

## Regression & Bugs (~06:47)

**[M]** Some of them are regression. When you say "regression" — that should be a post-development bug, isn't it?

Yeah, usually they are currently found by automation.

**[A]** Sorry — when you say "open defects", are these post-development bugs, or both?

**[M]** I think Hongyan didn't separate them, but she can in the future. Right now they have columns: catalog regression, post-bug boxes for new features are... bug boxes.

**[K]** Yeah, OK. That's what I wanted to hear. Regression clearly is a post-development bug. For new features, it has to be a bug. We discussed this briefly last week.

Let's spend a few minutes on understanding bugs here — temporarily until we align.

Given we have a unique situation: a feature is shared by multiple teams. A story developed by backend, tested with unit testing... but in general when feature validation happens via a QA testing story...

I like the idea Chris had last week:

> The bugs identified by that QA testing story should be captured as a **new story**, but linked to the same feature.

Earlier we were doing something similar — we kept some allocation to support new feature testing bugs/defects in the old audio, and assigned that story to a developer. We should do the same: link the QA story's bugs to this developer story.

OK, so:
- The testing story that runs the test cases itself should NOT have any bugs linked to it
- That story itself can be moved to done once testing activities are complete
- But this **separate bug story**, now with bugs linked to it — owned by the developer team — that will remain open until all those bugs are resolved

Let's follow this. There is a meeting scheduled tomorrow with Aaron and the team on bugs and recommendations for this scenario. I'll share the outcome tomorrow in our next meeting.

I cannot send that message out until we have alignment on these types of scenarios, OK?

So please separate this out: post-development bugs and regular bugs. Both are impacting the pass rates here.

Both teams — Mango, Tomato, Avocado — please take a look, whichever team you're on. At feature level, product owners — look at the bugs associated to that feature story, then process that in your standups.

Bugs reported in an iteration **must be resolved within the same iteration** if linked to a story. Otherwise — for a testing story executed in this iteration with bugs reported — POs can plan the effort to resolve bugs through a separate story in the next iteration.

But POs, please actively look at bugs **daily** in the standup.

---

## Romana / Quality Mindset (~11:10)

**[N]** Yes, this is directed to all product leads, directors, POs, and anyone leading a team:

**Regression is doing exactly what it is supposed to do.**

Guys, I know it seems dire. But remember this is an experiment — OK? This is the first one we're trying like this, and I think we're the only team doing regression this way during iteration testing.

So yes: it's dire, but **it's doing what it's supposed to do**. We are trying to improve quality early. This is actually a good thing.

Imagine if this was only a few-month release and everything was found out at the very last minute. What I'm saying is: we should champion this kind of quality process that identifies issues **earlier** in a release.

**[M]** Judy also sent mail with analysis for this low pass rate. This also caused a lot of user stories to carry over to the next iteration. This will impact our final dates for completion.

I have questions about that. Is there like a major disconnect between dev and QA? How are we getting all these failures? Is it exploratory testing? What's going on here?

**[M]** These reports are based on the test cases, not exploratory. These are the test cases that were written.

So is dev not testing?

Yeah, I think in that mail we identified some analysis points. Some of the root causes:
- Even the main workflow cannot pass on our QA side for some user stories
- Insufficient coverage on business scenarios

Previously we had a kind of video, and dev may look at that. Maybe they can know some test scenarios. But right now to us it appears insufficient.

**[O]** If there's insufficient acceptance criteria coverage — then it is what it is. That doesn't mean we should...

I mean, we need to align on what the acceptance criteria **is**. If criteria is missing, QA shouldn't just start adding new acceptance criteria that wasn't there.

**[K]** Yeah, Chris — can we pick a few features and do root cause analysis working with Team Mango? Looking at both reported bugs plus the test cases they have — whether these should be real bugs or false positives?

We should spend some time going through this. It's a good exercise to avoid this in the future, right? Let's take this as a retrospective item, do RCA, and align with Team Mango, plus get alignment on expectations and process.

---

## Quick Practice Extract (high-frequency phrases you can copy)

| Meeting Pattern | Example |
|-----------------|---------|
| Open softly while waiting | People are still coming in. Let's wait a few more seconds. |
| Reference pre-meeting notes | As I put in the chat yesterday... |
| Objective project status | Technically, we are about halfway through... |
| Cascade impact | impact downwards for BI objectives / CP5 milestones |
| Add next topic | In addition to that, we will also discuss... |
| Call to action | Please clean up the board |
| Ask for status update | Can someone comment on...? |
| Call out data point | Even with pass rate like 20% — that's quite low |
| Alignment language | There is no major change, right? |
| Propose practice going forward | Let's follow this / let's spend time here |
| Ask for follow-up | Can you please follow up on this? |

