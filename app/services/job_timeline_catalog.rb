module JobTimelineCatalog
  STATUS_CLASSES = {
    'printing' => 'job-timeline-segment--printing',
    'paused' => 'job-timeline-segment--paused',
    'attention' => 'job-timeline-segment--attention',
    'error' => 'job-timeline-segment--error',
    'finished' => 'job-timeline-segment--finished',
    'cancelled' => 'job-timeline-segment--cancelled',
    'pending' => 'job-timeline-segment--pending'
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
    'started' => 'job-timeline-mark--success',
    'resumed' => 'job-timeline-mark--success',
    'attention' => 'job-timeline-mark--danger',
    'error' => 'job-timeline-mark--danger',
    'paused' => 'job-timeline-mark--warning',
    'finished' => 'job-timeline-mark--muted',
    'cancelled' => 'job-timeline-mark--muted',
    'status_changed' => 'job-timeline-mark--muted'
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
