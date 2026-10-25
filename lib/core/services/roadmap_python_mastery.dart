import '../models/enums.dart';
import '../models/goal.dart';
import '../models/milestone.dart';
import '../models/note.dart';
import '../models/subject.dart';
import '../models/topic.dart';
import '../utils/date_format.dart';
import 'app_database.dart';
import 'repository.dart';

/// Tag put on everything this roadmap creates, so it can be found and never imported twice.
const pythonRoadmapTag = 'python-mastery-2027';

class RoadmapResult {
  const RoadmapResult({this.goals = 0, this.milestones = 0, this.topics = 0, this.notes = 0, this.alreadyImported = false});
  final int goals, milestones, topics, notes;
  final bool alreadyImported;
}

class _Subj {
  const _Subj(this.name, this.category, this.icon, this.color, this.hours);
  final String name, category, icon;
  final int color;
  final double hours;
}

const _subjects = <String, _Subj>{
  'python': _Subj('Python', 'Programming', 'code', 0xFF2563EB, 200),
  'dsa': _Subj('Data Structures & Algorithms', 'Problem solving', 'psychology', 0xFF7C3AED, 250),
  'sql': _Subj('SQL & Databases', 'Data', 'data', 0xFF0E7490, 60),
  'api': _Subj('FastAPI & Backend', 'Backend', 'api', 0xFF059669, 90),
  'devops': _Subj('DevOps', 'Systems', 'build', 0xFFEA580C, 50),
};

class _Phase {
  const _Phase(this.title, this.subject, this.start, this.end, this.hours, this.topics, this.milestone, this.criteria);
  final String title, subject, topics, milestone, criteria;
  final DateTime start, end;
  final int hours;
}

final _phases = <_Phase>[
  _Phase('Phase 1 — Python foundations', 'python', DateTime(2026, 10, 1), DateTime(2026, 11, 30), 55,
      'Variables, data types, input/output, operators, conditions, loops, patterns, strings, lists, tuples, sets, dictionaries, functions and basic problem-solving.',
      'Write small programs without tutorials', 'Weekly tests at 80%+; Project 1 (Personal Finance CLI) finished'),
  _Phase('Phase 2 — Functions, files and OOP', 'python', DateTime(2026, 12, 1), DateTime(2026, 12, 31), 50,
      'Modules, packages, exceptions, text/CSV/JSON files, classes, objects, inheritance, composition, encapsulation, polymorphism, iterators and generators.',
      'Build a modular command-line application', 'Project 2 (Inventory & Billing) with tests; business logic separate from I/O'),
  _Phase('Phase 3 — Core DSA', 'dsa', DateTime(2027, 1, 1), DateTime(2027, 1, 31), 50,
      'Big-O, arrays/lists, strings, hashing, searching, sorting, two pointers, sliding windows, stacks, queues and linked lists.',
      'Explain and implement common data structures and patterns', 'Implement each structure from memory and state its complexity'),
  _Phase('Phase 4 — Advanced DSA and algorithms', 'dsa', DateTime(2027, 2, 1), DateTime(2027, 3, 31), 95,
      'Recursion, backtracking, trees, heaps, binary search patterns, greedy algorithms, graphs, BFS, DFS, dynamic programming and complexity analysis.',
      'Solve unfamiliar medium-level problems with a clear approach', 'Project 3 (DSA Visualizer) with 5+ algorithms verified against built-ins'),
  _Phase('Phase 5 — Databases and data handling', 'sql', DateTime(2027, 4, 1), DateTime(2027, 4, 30), 48,
      'SQL, MySQL, joins, grouping, subqueries, indexes, transactions, Python database connectivity, CSV/JSON, NumPy, pandas and data visualization.',
      'Build a data-driven application backed by a database', 'Project 4 (Financial Data Analyzer) correct on empty, duplicate, missing and invalid data'),
  _Phase('Phase 6 — Advanced Python and backend engineering', 'api', DateTime(2027, 5, 1), DateTime(2027, 6, 30), 95,
      'Decorators, context managers, type hints, dataclasses, testing, logging, profiling, concurrency basics, FastAPI, HTTP, REST, authentication, validation and database integration.',
      'Deliver a tested, documented backend API', 'Documented API, tests for success and failure, protected endpoints'),
  _Phase('Phase 7 — Engineering tools and application development', 'devops', DateTime(2027, 7, 1), DateTime(2027, 7, 31), 48,
      'Tkinter, Git/GitHub, Linux, command-line tools, Docker fundamentals, environment variables, CI basics and deployment.',
      'Run and troubleshoot your own applications', 'Project 5 (Finance REST API) deployed with reproducible instructions'),
  _Phase('Phase 8 — Interview readiness and capstone', 'dsa', DateTime(2027, 8, 1), DateTime(2027, 9, 30), 95,
      'Timed DSA sets, SQL assessments, Python internals review, debugging, system-design fundamentals, mock interviews, project walkthroughs and resume refinement.',
      'Demonstrate skills under interview conditions', 'Project 6 capstone finished; mock interviews passed'),
];

class _Topic {
  const _Topic(this.subject, this.name, this.phase, [this.minutes = 180]);
  final String subject, name;
  final int phase, minutes;
}

/// The 42-item syllabus tracker, grouped by the phase in which it is studied (0-based).
const _syllabus = <_Topic>[
  // A. Foundations
  _Topic('python', 'Variables, naming and data types', 0),
  _Topic('python', 'Input/output, operators and type conversion', 0),
  _Topic('python', 'Conditions and Boolean logic', 0),
  _Topic('python', 'Loops, nested loops and pattern programming', 0),
  _Topic('python', 'Strings, indexing, slicing and string methods', 0),
  _Topic('python', 'Lists, tuples, sets and dictionaries', 0),
  _Topic('python', 'Functions, parameters, return values and scope', 0),
  // B. Python fluency
  _Topic('python', 'Comprehensions and unpacking', 1),
  _Topic('python', 'Modules, imports, packages and virtual environments', 1),
  _Topic('python', 'Exceptions and custom exceptions', 1),
  _Topic('python', 'Text, CSV, JSON and filesystem operations', 1),
  _Topic('python', 'OOP: classes, objects, inheritance and polymorphism', 1),
  _Topic('python', 'Composition, abstraction, properties and special methods', 1),
  _Topic('python', 'Iterators, generators, decorators and context managers', 5),
  _Topic('python', 'Type hints, dataclasses and standard-library tools', 5),
  // C. DSA
  _Topic('dsa', 'Time/space complexity and Big-O', 2),
  _Topic('dsa', 'Arrays, strings, hashing and frequency maps', 2),
  _Topic('dsa', 'Searching, sorting and binary search', 2),
  _Topic('dsa', 'Two pointers, sliding windows and prefix sums', 2),
  _Topic('dsa', 'Stacks, queues and linked lists', 2),
  _Topic('dsa', 'Recursion and backtracking', 3),
  _Topic('dsa', 'Trees, BSTs, heaps and priority queues', 3, 240),
  _Topic('dsa', 'Greedy algorithms and proof of correctness', 3),
  _Topic('dsa', 'Graphs, BFS, DFS and topological sorting', 3, 240),
  _Topic('dsa', 'Dynamic programming and memoization', 3, 300),
  // D. Databases and data
  _Topic('sql', 'SQL: SELECT, filtering, sorting and aggregation', 4),
  _Topic('sql', 'Joins, subqueries, CTEs and window functions', 4, 240),
  _Topic('sql', 'Keys, constraints, normalization and indexes', 4),
  _Topic('sql', 'Transactions and database connectivity', 4),
  _Topic('python', 'CSV/JSON processing and data validation', 4),
  _Topic('python', 'NumPy arrays and vectorized operations', 4),
  _Topic('python', 'pandas cleaning, grouping and transformations', 4, 240),
  _Topic('python', 'Data visualization and interpreting results', 4),
  // E. Applications and engineering
  _Topic('python', 'Tkinter widgets, events, layouts and validation', 6),
  _Topic('api', 'FastAPI routes, request/response models and Pydantic', 5, 240),
  _Topic('api', 'REST, HTTP status codes and API design', 5),
  _Topic('api', 'SQLAlchemy or another ORM and migrations', 5),
  _Topic('api', 'Authentication, authorization and secure configuration', 5, 240),
  _Topic('python', 'Unit tests, integration tests and mocking', 5),
  _Topic('python', 'Logging, debugging, profiling and refactoring', 5),
  _Topic('python', 'Async/await and concurrency fundamentals', 5),
  _Topic('devops', 'Git, Linux, Docker, CI and deployment', 6, 300),
];

class _Project {
  const _Project(this.title, this.due, this.skills, this.pass);
  final String title, skills, pass;
  final DateTime due;
}

final _projects = <_Project>[
  _Project('Project 1 — Personal Finance CLI', DateTime(2026, 11, 30),
      'Conditions, loops, functions, lists, dictionaries, files, exceptions.',
      'Correct totals, invalid-input handling, persistence after restart, 15+ meaningful tests.'),
  _Project('Project 2 — Inventory and Billing System', DateTime(2026, 12, 31),
      'OOP, modules, exceptions, file handling, unit tests, clean architecture.',
      'Prevent invalid stock changes, handle edge cases, separate business logic from I/O, automated tests.'),
  _Project('Project 3 — DSA Visualizer', DateTime(2027, 2, 28),
      'Searching, sorting, stacks, queues, recursion, complexity analysis, Tkinter.',
      '5+ algorithms, complexity explained, results verified against Python built-ins.'),
  _Project('Project 4 — Financial Data Analyzer', DateTime(2027, 4, 30),
      'SQL, MySQL, CSV, pandas, NumPy, visualization, data validation.',
      'Correct for empty files, duplicates, missing fields, invalid dates and large datasets.'),
  _Project('Project 5 — Finance Management REST API', DateTime(2027, 7, 31),
      'FastAPI, SQL, authentication, authorization, validation, testing, deployment.',
      'Documented API, tests for success and failure, protected endpoints, secure passwords, reproducible deployment.'),
  _Project('Project 6 — Production-Quality Capstone', DateTime(2027, 9, 30),
      'Migrations, audit logs, role-based permissions, import/export, reporting, tests, Docker, CI.',
      'Design, implement (no AI-generated code), test, debug, explain trade-offs and deploy a feature.'),
];

const _notes = <(String, String)>[
  (
    'Python roadmap — daily and weekly routine',
    '''Weekday routine · 70 minutes
- 10 min  Recall yesterday: write definitions or recreate yesterday's code without notes.
- 20 min  Learn one concept, then explain it in your own words.
- 25 min  Code independently: 2–3 exercises or one harder problem.
- 10 min  DSA practice: one problem at your level.
-  5 min  Learning log: errors, what you learned, tomorrow's target.

Saturday: 30–45 min light revision or a small test.

Sunday deep work · 3–4 hours
1. 45 min review the week from memory
2. 60 min solve 2–3 DSA problems and analyse complexity
3. 60–90 min implement or improve the current project
4. 30 min closed-book test, then review mistakes

DSA starts in week one (10–15 min a day), it does not wait for January.'''
  ),
  (
    'Python roadmap — assessments and pass rules',
    '''Schedule
- Daily: write one function from memory, answer three concept questions, solve a small exercise.
- Weekly: 30–45 min closed-book (output prediction, 2 coding exercises, 1 debugging task, short explanation).
- Monthly: 60–90 min milestone exam covering older topics too, plus a small practical.
- Final: interview simulation — timed DSA, Python round, SQL, project walkthrough.

Pass rules
- Weekly test: 80%+      - Monthly assessment: 80%+
- Independent coding work: 80%+ of assigned exercises
- Project: all critical tests pass
- Missed questions: re-solved after 3–7 days
- Code explanation: logic, edge cases and complexity

Below 80%? Fix the weakest concept in the next session, then retest with different questions.

DSA targets (250–350 reviewed problems by Sep 2027): Oct–Dec 30–50, Jan–Mar 80–100, Apr–Jun 70–90, Jul–Sep 70–100.
Keep a problem log: pattern, first approach, complexity, mistakes, date re-solved.'''
  ),
  (
    'Python roadmap — AI-independence protocol',
    '''AI may accelerate learning, but it must not replace reasoning.

1. Think independently (5–10 min): inputs, expected outputs, edge cases, plain-English algorithm — before opening AI.
2. Implement it yourself, even if imperfect. Run examples, read the errors.
3. Ask AI for a hint, not the answer: a conceptual mistake, an error explained, a counterexample.
4. Debug and verify: reproduce, isolate, fix, add a regression test. Never assume generated code is correct.
5. Rebuild without AI the next day: recreate the logic from memory, explain why it works and its complexity.

Mentor prompt
"Act as my Python mentor. I am preparing for software engineering interviews by September 2027 and want to become independent of AI-generated code. Teach me the concept step by step. Do not give the complete solution immediately; ask me to propose an approach; give progressively stronger hints; review my code for correctness, readability, edge cases and complexity; make me debug before revealing causes; give me a new similar problem; make me explain the logic in my own words.
Today's topic: [TOPIC]. My attempt: [CODE]. My difficulty: [PROBLEM]."'''
  ),
];

/// Adds the Python Mastery roadmap (Oct 2026 – Sep 2027) to the signed-in account:
/// eight phase goals with milestones, a master goal with the six projects, a DSA
/// problem-count goal, the 42-topic syllabus and three reference notes.
///
/// Nothing is seeded automatically; this runs only when the user asks for it, and
/// never twice (everything it creates is tagged [pythonRoadmapTag]).
Future<RoadmapResult> importPythonMasteryRoadmap(Repository repo, {DateTime? today}) async {
  if ((await repo.goals()).any((g) => g.tagList.contains(pythonRoadmapTag))) {
    return const RoadmapResult(alreadyImported: true);
  }
  final now = dayOnly(today ?? DateTime.now());

  // Reuse subjects the user already has (by name); create the rest.
  final existing = {for (final s in await repo.subjects()) s.name.toLowerCase(): s};
  final subjects = <String, Subject>{};
  for (final e in _subjects.entries) {
    final def = e.value;
    var s = existing[def.name.toLowerCase()];
    if (s == null) {
      s = Subject(
          name: def.name, category: def.category, icon: def.icon, color: def.color, targetHours: def.hours);
      await repo.saveSubject(s);
    }
    subjects[e.key] = s;
  }

  var goals = 0, milestones = 0, topics = 0, notes = 0;
  final phaseGoals = <Goal>[];
  for (var i = 0; i < _phases.length; i++) {
    final p = _phases[i];
    final start = !p.start.isAfter(now) && !p.end.isBefore(now) ? now : p.start;
    final g = Goal(
      title: p.title,
      description: p.topics,
      subjectId: subjects[p.subject]!.id,
      startDate: start,
      deadline: p.end,
      estimatedMinutes: p.hours * 60,
      remainingMinutes: p.hours * 60,
      priority: 3,
      status: !p.start.isAfter(now) && !p.end.isBefore(now) ? GoalStatus.inProgress : GoalStatus.notStarted,
      tags: '$pythonRoadmapTag, roadmap',
      criteria: p.criteria,
    );
    await repo.saveGoal(g);
    phaseGoals.add(g);
    goals++;
    await repo.saveMilestone(Milestone(
        goalId: g.id, title: p.milestone, dueDate: p.end, criteria: p.criteria, estimatedMinutes: 0));
    await repo.saveMilestone(Milestone(
        goalId: g.id,
        title: 'Phase assessment — score 80% or more',
        dueDate: p.end,
        criteria: 'Closed-book test on this phase plus older topics; re-test weak areas if below 80%'));
    milestones += 2;
  }

  final master = Goal(
    title: 'Python Mastery & Interview Readiness — 30 Sep 2027',
    description:
        'Python mastery, MNC interview readiness (DSA, SQL, CS fundamentals) and independent engineering with FastAPI and real projects. '
        'Targets: Google, Atlassian, Amazon, CRED, Mastercard, Visa, Flipkart, Jio, Zepto, Swiggy, Zomato.',
    subjectId: subjects['python']!.id,
    startDate: now,
    deadline: DateTime(2027, 9, 30),
    priority: 3,
    status: GoalStatus.inProgress,
    manualProgress: 0,
    tags: '$pythonRoadmapTag, roadmap',
    criteria: 'Weekly and monthly tests at 80%+; six projects delivered; timed interview simulation passed',
  );
  await repo.saveGoal(master);
  goals++;
  for (final pr in _projects) {
    await repo.saveMilestone(Milestone(
        goalId: master.id, title: pr.title, description: pr.skills, dueDate: pr.due, criteria: pr.pass));
    milestones++;
  }
  await repo.saveMilestone(Milestone(
      goalId: master.id,
      title: 'Final interview simulation',
      dueDate: DateTime(2027, 9, 25),
      criteria: 'Timed DSA questions, Python round, SQL problems and a project walkthrough without notes'));
  milestones++;

  final dsa = Goal(
    title: 'Solve 250–350 reviewed DSA problems',
    description:
        'Patterns over counts. Keep a problem log (pattern, first approach, complexity, mistakes, date re-solved) and re-solve mistakes after 3–7 days.',
    subjectId: subjects['dsa']!.id,
    startDate: now,
    deadline: DateTime(2027, 9, 30),
    priority: 3,
    status: GoalStatus.inProgress,
    manualProgress: 0,
    tags: '$pythonRoadmapTag, roadmap, dsa',
    criteria: '250–350 problems solved and reviewed, mistakes re-solved independently',
  );
  await repo.saveGoal(dsa);
  goals++;
  for (final (title, due) in [
    ('Reach 30–50 foundational problems', DateTime(2026, 12, 31)),
    ('Reach 110–150 problems (core patterns)', DateTime(2027, 3, 31)),
    ('Reach 180–240 problems (more mediums)', DateTime(2027, 6, 30)),
    ('Reach 250–340 problems (timed sets)', DateTime(2027, 9, 30)),
  ]) {
    await repo.saveMilestone(Milestone(goalId: dsa.id, title: title, dueDate: due));
    milestones++;
  }

  // Syllabus topics, skipping any the user already has under that subject.
  final have = <String>{for (final t in await repo.topics()) '${t.subjectId}|${t.name.toLowerCase()}'};
  for (final t in _syllabus) {
    final s = subjects[t.subject]!;
    if (!have.add('${s.id}|${t.name.toLowerCase()}')) continue;
    await repo.saveTopic(Topic(
        subjectId: s.id,
        goalId: phaseGoals[t.phase].id,
        name: t.name,
        estimatedMinutes: t.minutes,
        difficulty: t.phase >= 3 ? 'Intermediate' : 'Beginner'));
    topics++;
  }

  for (final (title, body) in _notes) {
    await repo.saveNote(Note(title: title, body: body, goalId: master.id, tags: pythonRoadmapTag, favorite: false));
    notes++;
  }
  return RoadmapResult(goals: goals, milestones: milestones, topics: topics, notes: notes);
}

const _roadmapPref = 'roadmap_python_2027_added';

/// Feeds the roadmap into an account the first time it is opened. A preference
/// remembers that this happened, so deleting the roadmap later does not bring it back.
Future<RoadmapResult?> addPythonRoadmapOnce(AppDatabase db) async {
  if (await db.pref(_roadmapPref) != null) return null;
  final r = await importPythonMasteryRoadmap(Repository(db));
  await db.setPref(_roadmapPref, '1');
  return r;
}
