
T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum GoalStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  paused('Paused'),
  completed('Completed'),
  archived('Archived');

  const GoalStatus(this.label);
  final String label;
}

enum SessionType {
  learning('Learning'),
  codingPractice('Coding practice'),
  revision('Revision'),
  projectWork('Project work'),
  reading('Reading'),
  interviewPrep('Interview prep'),
  other('Other');

  const SessionType(this.label);
  final String label;
}

enum SessionStatus { running, paused, completed, discarded }

enum ActivityKind {
  study('Study'),
  revision('Revision'),
  practice('Practice'),
  project('Mini-project'),
  assessment('Assessment'),
  deadline('Deadline'),
  milestone('Milestone');

  const ActivityKind(this.label);
  final String label;
}

enum ProblemResult {
  solved('Solved'),
  attempted('Attempted'),
  needsRevision('Needs Revision'),
  unsolved('Unsolved');

  const ProblemResult(this.label);
  final String label;
}

const difficulties = ['Beginner', 'Intermediate', 'Advanced'];

const problemDifficulties = ['Easy', 'Medium', 'Hard'];

const platforms = ['LeetCode', 'HackerRank', 'Codeforces', 'GeeksforGeeks', 'Custom'];

const priorityLabels = {1: 'Low', 2: 'Medium', 3: 'High'};
