#!/usr/bin/env ruby

##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

msf_base = __FILE__
while File.symlink?(msf_base)
  msf_base = File.expand_path(File.readlink(msf_base), File.dirname(msf_base))
end

$:.unshift(File.expand_path(File.join(File.dirname(msf_base), '..', 'lib')))
require 'rex/java/serialization'
require 'pp'
require 'optparse'

# This class allows to deserialize Java Streams from
# files
class JavaDeserializer

  # @!attribute file
  #   @return [String] the file's path to deserialize
  attr_accessor :file

  # @param file [String] the file's path to deserialize
  def initialize(file = nil)
    self.file = file
  end

  # Deserializes a Java stream from a file and prints the result.
  #
  # @return [Rex::Java::Serialization::Model::Stream] if succeeds
  # @return [nil] if error
  def run(options = {})
    if file.nil?
      print_error("file path with serialized java stream required")
      return
    end

    print_status("Deserializing...")
    print_line

    begin
      f = File.new(file, 'rb')
      stream = Rex::Java::Serialization::Model::Stream.decode(f)
      f.close
    rescue ::Exception => e
      print_exception(e)
      return
    end

    if options[:array]
      print_array(stream.contents[options[:array].to_i])
    elsif options[:object]
      print_object(stream.contents[options[:object].to_i])
    else
      puts stream
    end
  end

  private

  # @param [String] string to print as status
  def print_status(msg='')
    $stdout.puts "[*] #{msg}"
  end

  # @param [String] string to print as error
  def print_error(msg='')
    $stdout.puts "[-] #{msg}"
  end

  # @param [Exception] exception to print
  def print_exception(e)
    print_error(e.message)
    e.backtrace.each do |line|
      $stdout.puts("\t#{line}")
    end
  end

  def print_line
    $stdout.puts("\n")
  end

  # @param [Rex::Java::Serialization::Model::NewObject] obj the object to print
  # @param [Fixnum] level the indentation level when printing super classes
  def print_object(obj, level = 0)
    prefix = "  " * level
    if obj.class_desc.description.class == Rex::Java::Serialization::Model::NewClassDesc
      puts "#{prefix}Object Class Description:"
      print_class(obj.class_desc.description, level + 1)
    else
      puts "#{prefix}Object Class Description: #{obj.class_desc.description}"
    end
    puts "#{prefix}Object Data: #{obj.class_data}"
  end

  # @param [Rex::Java::Serialization::Model::NewClassDesc] c the class to print
  # @param [Fixnum] level the indentation level when printing super classes
  def print_class(c, level = 0)
    prefix = "  " * level
    puts "#{prefix}Class Name: #{c.class_name}"
    puts "#{prefix}Serial Version: #{c.serial_version}"
    puts "#{prefix}Flags: #{c.flags}"
    puts "#{prefix}Fields ##{c.fields.length}"
    c.fields.each do |f|
      puts "#{prefix}Field: #{f}"
    end
    puts "#{prefix}Class Annotations ##{c.class_annotation.contents.length}"
    c.class_annotation.contents.each do |c|
      puts "#{prefix}Annotation: #{c}"
    end
    puts "#{prefix}Super Class: #{c.super_class}"
    if c.super_class.description.class == Rex::Java::Serialization::Model::NewClassDesc
      print_class(c.super_class.description, level + 1)
    end
  end

  # @param [Rex::Java::Serialization::Model::NewArray] arr the array to print
  # @param [Fixnum] level the indentation level when printing super classes
  def print_array(arr, level = 0)
    prefix = "  " * level
    puts "#{prefix}Array Description"
    print_class(arr.array_description.description, 1)
    puts "#{prefix}Array Type: #{arr.type}"
    puts "#{prefix}Array Values ##{arr.values.length}"
    arr.values.each do |v|
      puts "Array value: #{prefix}#{v} (#{v.class})"
      if v.class == Rex::Java::Serialization::Model::NewObject
        print_object(v, level + 1)
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: java_deserializer.rb <file> [option]"

    opts.on("-aID", "--array=ID", "Print detailed information about content array") do |id|
      options[:array] = id
    end

    opts.on("-oID", "--object=ID", "Print detailed information about content object") do |id|
      options[:object] = id
    end

    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!

  if options.length > 1
    $stdout.puts "[-] Don't provide more than one option"
    exit
  end

  deserializer = JavaDeserializer.new(ARGV[0])
  deserializer.run(options)
end
