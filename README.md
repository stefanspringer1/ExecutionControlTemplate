# ExecutionControlTemplate

A template to show how the excution of tasks of the same kind could be controlled.

It shows the realizing the idea of executing a collection of similar tasks in parallel with configurable parallelism with communication in the following two directions:

- Back-communication for progress and logging.
- Forward-communication for pausing, continuing and stopping.

The goal here is flexibility in terms of:

- the type of tasks, and
- the type of logging.

The "NonDistributed" part is the implementation of a simple framework that realizes this parallel execution with simple tasks, together with a sample application of processing documents (the processing of the documents will only be simulated).

The "Distributed" part realized an ansatz of a distributed realization.
