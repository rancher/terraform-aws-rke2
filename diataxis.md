# Prompts to use

## 1. The "System Role" Master Prompt
Use this prompt first to establish the framework, rules, and mindset before generating any actual content.

**Prompt:**
```text
You are an expert technical writer specializing in the Diátaxis framework. Your goal is to help me write documentation structured strictly around its four distinct user needs: Tutorials (learning-oriented), How-to Guides (goal-oriented), Reference (information-oriented), and Explanation (understanding-oriented).

You must strictly maintain the boundaries between these four types. Do not mix them. For example, a How-to guide should not explain underlying architectural concepts, and a Reference document should not contain a step-by-step tutorial.

Acknowledge your role and understanding of the Diátaxis framework, and wait for my next instruction.
```

## 2. Prompt for Tutorials (Learning-Oriented)
Use this when you want to guide a beginner through a learning experience.

**Prompt:**
```text
I need you to write a Tutorial for [Insert Topic/Tool]. A tutorial in Diátaxis is entirely learning-oriented and designed for a beginner to achieve a small, successful outcome under your guidance. Follow these strict rules:

**Goal:** Focus on teaching, not just doing. Help the user acquire a new skill or familiarity.

**Structure:** Make it a series of linear, step-by-step actions that are guaranteed to work.

**Tone:** Encouraging, authoritative, and instructional (like a teacher guiding a student).

**What to exclude:** Do not include alternative methods, deep background explanations, or exhaustive edge cases. Stick to one clear path to success.

The specific task the user will accomplish in this tutorial is: [Insert Task, e.g., 'Creating their first API endpoint'].
```

## 3. Prompt for How-to Guides (Goal-Oriented)
Use this when a user already knows the basics but needs to solve a specific problem.

**Prompt:**
```text
I need you to write a How-to Guide for [Insert Topic/Tool]. A how-to guide in Diátaxis is goal-oriented and designed for a practitioner who already understands the basics but needs to accomplish a specific real-world task. Follow these strict rules:

**Goal:** Solve a specific problem or answer the question: 'How do I do X?'

**Structure:** Provide a logical sequence of steps. Unlike a tutorial, it assumes the user is already capable, so focus on the action rather than teaching foundational concepts.

**Tone:** Practical, direct, and outcome-focused.

**What to exclude:** Do not explain why things work under the hood (that belongs in Explanation) and do not list every single API parameter (that belongs in Reference).

The specific goal of this guide is: [Insert Goal, e.g., 'How to migrate a database from version 1 to version 2'].
```

## 4. Prompt for Technical Reference (Information-Oriented)
Use this to create clear, unbloated documentation of the technical facts.

**Prompt:**
```text
I need you to write a Technical Reference document for [Insert API, Function, Code Library, or Command]. A reference document in Diátaxis is strictly information-oriented and serves a user who is currently in the middle of working and needs hard facts. Follow these strict rules:

**Goal:** Describe the machinery accurately and completely.

**Structure:** Organize it systematically (e.g., lists of parameters, data types, return values, configurations, or syntax options).

**Tone:** Neutrally objective, concise, and literal. Avoid narrative prose.

**What to exclude:** Do not include step-by-step instructions on how to use it for a project, and do not include historical background or discussions on architecture.

The specific component you need to document is: [Insert Component Name/Details].
```

## 5. Prompt for Explanation (Understanding-Oriented)
Use this when the user needs context, architecture, or the "why" behind the technology.

**Prompt:**
```text
I need you to write an Explanation document for [Insert Concept/System]. An explanation document in Diátaxis is understanding-oriented and serves a user who wants to step back from coding to comprehend the system better. Follow these strict rules:

**Goal:** Provide illumination, context, and clear background. Answer the questions 'Why?' and 'How does it work together?'

**Structure:** Use a topical approach, discussing architectural choices, design philosophy, security implications, or historical context.

**Tone:** Discursive, analytical, and explanatory. You can explore multiple perspectives, alternatives, and trade-offs.

**What to exclude:** Do not include step-by-step instructions, commands to copy-paste, or exhaustive API tables.

The specific architectural concept or topic to explain is: [Insert Topic, e.g., 'How our authentication flow handles JWT tokens'].
```
