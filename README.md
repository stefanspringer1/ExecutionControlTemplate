# ExecutionControlTemplate

A template to show how the excution of tasks of the same kind could be controlled.

It shows the realization of the idea of parallel execution of work items with configurable parallelism with communication in the following two directions:

- Back-communication for progress and logging.
- Forward-communication for pausing, continuing and stopping.

The "NonDistributed" part is the implementation of a simple framework that allows the (parallel) execution of workers for the same type of work items, together with a sample application of processing documents (the processing of the documents will only be simulated).

The "Distributed" part realized an ansatz of a distributed realization.
