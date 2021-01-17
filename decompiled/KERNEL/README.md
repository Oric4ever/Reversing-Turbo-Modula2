The Kernel module is responsible for the handling of exceptions.
In order to protect against OutOfMemory (eg. stack overflow),
this module starts a separate coroutine that will be TRANSFERed to 
by the MCode interpreter when an exception occurs.
One of the exception is related to the handling of Overlays (modules whose code
share the same area of memory): the code of these modules is automatically 
reloaded from the M2.OVR file when they are needed.
