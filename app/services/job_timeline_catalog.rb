module JobTimelineCatalog
  STATUS_CLASSES = {
    'printing' => 'job-timeline__segment--printing',
    'paused' => 'job-timeline__segment--paused',
    'attention' => 'job-timeline__segment--attention',
    'error' => 'job-timeline__segment--error',
    'finished' => 'job-timeline__segment--finished',
    'cancelled' => 'job-timeline__segment--cancelled',
    'pending' => 'job-timeline__segment--pending'
  }.freeze

  STATUS_LABELS = {
    'printing' => 'Printing',
    'paused' => 'Paused',
    'attention' => 'Attention',
    'error' => 'Error',
    'finished' => 'Finished',
    'cancelled' => 'Cancelled',
    'pending' => 'Pending'
  }.freeze

  MARKER_CLASSES = {
    'started' => 'job-timeline__mark--success',
    'resumed' => 'job-timeline__mark--success',
    'attention' => 'job-timeline__mark--danger',
    'error' => 'job-timeline__mark--danger',
    'paused' => 'job-timeline__mark--warning',
    'finished' => 'job-timeline__mark--muted',
    'cancelled' => 'job-timeline__mark--muted',
    'status_changed' => 'job-timeline__mark--muted'
  }.freeze

  MARKER_SHORT_LABELS = {
    'started' => 'S',
    'resumed' => 'R',
    'attention' => 'A',
    'error' => 'E',
    'paused' => 'P',
    'finished' => 'F',
    'cancelled' => 'X',
    'status_changed' => 'C'
  }.freeze

  MARKER_LABELS = {
    'started' => 'Started',
    'resumed' => 'Resumed',
    'attention' => 'Attention',
    'error' => 'Error',
    'paused' => 'Paused',
    'finished' => 'Finished',
    'cancelled' => 'Cancelled',
    'status_changed' => 'Status change'
  }.freeze
end
