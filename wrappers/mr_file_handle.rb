class MrFileHandle
  attr_reader :ns_object

  def initialize(file_handle)
    # Handle NSPipe
    if file_handle.respond_to?(:fileHandleForReading)
      file_handle = file_handle.fileHandleForReading
    elsif file_handle.respond_to?(:fileHandleForWriting)
      file_handle = file_handle.fileHandleForWriting
    end

    @ns_object = file_handle
  end

  NOTIFICATIONS = {
    :connected      => NSFileHandleConnectionAcceptedNotification,
    :data_available => NSFileHandleDataAvailableNotification,
    :read_finished  => NSFileHandleReadCompletionNotification,
    :end_of_file    => NSFileHandleReadToEndOfFileCompletionNotification,
  }

  # Kick off a background read and call the block when the read is finished
  def read(&block)
    if block_given?
      read_in_background(:readInBackgroundAndNotify, :read_finished, &block)
    else
      MrUtils.string_from_data(@ns_object.read)
    end
  end

  # If a block is given:
  #   Kick off a background read and call the block with the String when EOF is reached
  # Otherwise:
  #   Synchonously read the data until EOF and return a String
  def read_to_end(&block)
    if block_given?
      read_in_background(:readToEndOfFileInBackgroundAndNotify, :end_of_file, &block)
    else
      MrUtils.string_from_data(@ns_object.readDataToEndOfFile)
    end
  end

  # The file descriptor number
  def fileno
    @ns_object.fileDescriptor
  end

  # Close the file
  def close
    @ns_object.closeFile
  end

  # Truncate the file at the offset
  def truncate(offset)
    @ns_object.truncateFileAtOffset(offset)
  end

private
  def read_in_background(selector, notification, &block)
    require "mr_notification_center"

    MrNotificationCenter.subscribe(self, notification) do |notification|
      data = notification.userInfo[NSFileHandleNotificationDataItem]

      if data.length > 0
        block.call MrUtils.string_from_data(data), notification
      end

      @ns_object.send(selector)
    end

    @ns_object.send(selector)
  end
end