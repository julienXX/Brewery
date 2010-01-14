require "mr_file_handle"
require "mr_utils"

# Mr Task is a NSTask wrapper that has gives MacRuby developers
# an API closer to what they would expect when using Ruby.
#
# For more information about NSTask, refer to:
# http://developer.apple.com/mac/library/documentation/cocoa/Reference/Foundation/Classes/NSTask_Class/Reference/Reference.html
class MrTask
  class InvalidExecutable < StandardError; end

  attr_reader :ns_object

  # The NSTaskDidTerminateNotification is mapped to :done when
  # using the MrNotificationCenter for a MrTask
  NOTIFICATIONS = {
    done: NSTaskDidTerminateNotification
  }

  # Creates a new task instance with a launch path and a directory.
  # The directory is the working directory from which you want the task
  # to be executed.
  #
  # An optional block can be run asynchronously after the task is done.
  # The block takes the task's output and the done notification.
  #
  # The new instance task still needs to be triggered by calling the +launch+
  # method on it.
  #
  # Example:
  #   task = MrTask.new("/bin/ls", from_directory:"/") do |output|
  #     puts output
  #   end
  #
  #   task.launch
  #
  def self.new(launch_path, from_directory:directory, &block)
    instance = new(launch_path, &block)
    instance.ns_object.currentDirectoryPath = directory
    instance
  end

  # Instantiates and launches a MrTask asynchronously. This method
  # takes an optional block that is passed to #new.
  #
  # Example:
  #   MrTask.launch("/bin/ls", "~/")
  # is equivalent to:
  #   MrTask.new("/bin/ls").launch("~/")
  def self.launch(cmd, *arguments, &block)
    new(cmd, &block).launch(*arguments)
  end

  def initialize(launch_path, &block)
    unless File.executable?(launch_path)
      raise InvalidExecutable, "#{launch_path} is not a valid executable"
    end

    @ns_object            = NSTask.alloc.init
    @ns_object.launchPath = launch_path
    @output               = ""
    @suspended            = 0

    # When a block is provided, it's a one-time event that gets
    # triggered with the output when the process terminates. This
    # is useful for "shelling out".
    if block_given?
      require "mr_notification_center"

      pipein, pipeout, pipeerr = pipe

      on_done do |notification|
        block.call standard_output, error_output, notification
      end
    end
    self
  end

  # Launches a MrTask instance.
  #
  # Optional arguments can be passed to launch, which will be sent
  # to the task when executed.
  #
  # Note: a task that was launched once cannot be launched another time.
  # If you try to do so, an exception will be raised.
  #
  # Usage:
  #   MrTask.new("/bin/ls").launch('/')
  def launch(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    args = args.first if args.first.is_a?(Array)

    self.pwd = options[:from_directory] if options[:from_directory]
    self.arguments ||= args
    @ns_object.launch

    return stdin, stdout
  end

  def standard_output(&block)
    @standard_output ||= stdout.read_to_end(&block)
  end

  def error_output(&block)
    @error_output ||= stderr.read_to_end(&block)
  end

  # Uses MrNotificationCenter in the background to monitor the status of your task.
  # As output streams back, the block that you passed is called with the output
  # and the original notification (NSFileHandleReadCompletionNotification).
  #
  # The block is triggered once for each chunk of output that comes back from
  # the task. This is especially useful for monitoring a running task.
  #
  # Usage:
  #   task = MrTask.new("/usr/bin/tail").on_output do |output|
  #     puts output
  #   end
  #
  #   task.launch("-f", "/var/log/apache2/access_log")
  def on_stdout(&block)
    pipein, pipeout, pipeerr = pipe
    pipeout.read(&block)
    self
  end

  def on_stderr(&block)
    pipein, pipeout, pipeerr = pipe
    pipeerr.read(&block)
    self
  end

  def on_output(&block)
    on_stdout(&block).on_stderr(&block)
  end

  # Pipes the output through new NSPipes. This means that you will not see
  # the output of the child task in the stdout of your main process.
  #
  # The first time this is called, it sets up the pipes. Every subsequent
  # time, it simply returns the streams.
  #
  # Returns [stdin, stdout, stderr] as MrFileHandles
  def pipe
    unless @ns_object.standardInput.respond_to?(:fileHandleForWriting)
      # Set stdin, stdout, and stderr to pipes
      @ns_object.standardInput  = NSPipe.alloc.init
      @ns_object.standardOutput = NSPipe.alloc.init
      @ns_object.standardError  = NSPipe.alloc.init
    end

    return stdin, stdout, stderr
  end

  # A MrFileHandle wrapping the standard input stream
  def stdin
    @stdin ||= MrFileHandle.new(@ns_object.standardInput)
  end

  # A MrFileHandle wrapping the standard output stream
  def stdout
    @stdout ||= MrFileHandle.new(@ns_object.standardOutput)
  end

  # A MrFileHandle wrapping the standard error stream
  def stderr
    @stderr ||= MrFileHandle.new(@ns_object.standardError)
  end

  # Synchronously waits for the task to be done
  def wait
    @ns_object.waitUntilExit
  end

  # Returns the arguments that were sent to the task
  def arguments
    @ns_object.arguments
  end

  # Sets the arguments for the task
  def arguments=(arguments)
    @ns_object.arguments = arguments
  end

  # Returns the task's current directory path
  def pwd
    @ns_object.currentDirectoryPath
  end

  # Sets the path that the task should be executed from
  def pwd=(directory)
    @ns_object.currentDirectoryPath = directory
  end

  # Returns the executable for the task
  def executable
    @ns_object.launchPath
  end

  # Send a SIGINT to the task
  def interrupt(&block)
    kill(:INT, &block) if running?
  end

  # Send a signal to the task (defaults to SIGTERM).
  #
  # If a block is provided, it registers an on_done event.
  def kill(signal = :TERM, &block)
    Process.kill(signal, @ns_object.processIdentifier) if running?
    on_done(&block) if block_given?
  end

  # Subscribe to an event that will be triggered when the process terminates.
  def on_done(&block)
    require "mr_notification_center"
    MrNotificationCenter.subscribe(self, :done, &block)
  end

  # Returns a boolean reflecting whether the task is still running
  def running?
    @ns_object.isRunning
  end

  # Returns the pid of the task
  def pid
    @ns_object.processIdentifier
  end

  # Returns true if the task is suspended. This does not reflect calls to suspend
  # made directly on the NSTask.
  def suspended?
    @suspended.nonzero?
  end

  # Suspends the task. You can only call suspend once. However, Cocoa supports suspending
  # a task multiple times (which requires multiple resumes to fully resume). If you want
  # to require multiple calls to resume to resume the task, use suspend!
  def suspend
    raise "You probably didn't mean to suspend multiple times. If you did, use suspend!" if suspended?
    suspend!
  end

  # Suspends the task. Multiple calls to suspend! require multiple calls to resume
  # to resume the task.
  def suspend!
    @suspended += 1
    @ns_object.suspend
  end

  # Resumes a suspended task. If suspend! was called multiple times, multiple calls
  # to resume will be required to resume the task.
  def resume
    @ns_object.resume
    @suspended -= 1
  end

  # Returns the status code for the task. Returns nil if the task is still running.
  def status
    @ns_object.terminationStatus unless running?
  end

  TERMINATION_REASONS = {
    NSTaskTerminationReasonExit => :exit,
    NSTaskTerminationReasonUncaughtSignal => :uncaught_signal
  }

  # Returns the reason for termination. This is one of :exit or :uncaught_signal.
  # This is not always available, even if the task is terminated. Returns nil
  # if the reason is unavailable or the task is still running.
  def reason
    @ns_object.terminationReason unless running?
  end
end