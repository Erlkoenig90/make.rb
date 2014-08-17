#!/usr/bin/env ruby

require 'continuation'
require 'set'

module MakeRb
  class MultiSpawn
    @@isWindows = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM)
  
    class JobError < StandardError
      def initialize(err)
        @err = err
      end
      def to_s
        @err
      end
    end
    
    
    # Escapes the given array of command line arguments into a string suitable for shell execution.
    # Is the inverse of {parseFlags}
    # @param [Array] args
    # @param String Where to redirect stdout
    # @return [String]
    def MultiSpawn.buildCmd(args, redirStdout = nil)
      # TODO - escaping here
      args.join(" ") + if(redirStdout == nil) then "" else " > #{redirStdout}" end
    end
    
    # Represents a running continuation
    class Job
      attr_accessor :cont, :procs
      def initialize
        @cont = nil
        @procs = []
      end
    end
    
    # Represents a running process
    class JProc
      attr_accessor :pid, :pipe, :out, :builder, :cmd, :strCmd, :job, :exitstatus
      def initialize(cmd_, pid_, pipe_, strCmd_, job_)
        @pid = pid_
        @pipe = pipe_
        @out = ""
        @cmd = cmd_
        @strCmd = strCmd_
        @job = job_
        @exitstatus = nil
      end

      def read(force = false)
        if(force)
          @out << @pipe.read
        else
          begin
            r = 0
            begin
              str = @pipe.read_nonblock(8*1024)
              r = str.length
              @out << str
              
#              puts "#{job} Read #{r} bytes"
            end while r > 0
          rescue IO::WaitReadable
            
          end
        end
      end

      def exited?
        @exitstatus != nil && @exitstatus.exited?
      end
    end
    
    
    def spawn(cmd, redirect = nil)
#      puts "spawn(#{cmd.inspect})"
      if(@currentJob == nil)
        raise "MultiSpawn#spawn may only be called from a job context!"
      end
      r, w = IO.pipe
      oh = {:out=>if(redirect != nil) then redirect else w end, :err=>w, :in=>if(@@isWindows) then "NUL" else "/dev/null" end }
      if(!@@isWindows)
        oh[r] = :close
      end
      proc = JProc.new(cmd, Process.spawn(*cmd, oh), r, MultiSpawn.buildCmd(cmd, redirect), @currentJob)
#      puts "spawn PID=" + proc.pid.to_s
      @procs << proc
      proc
    end
    def finish(proc)
      o = (proc.out.empty? ? "" : (proc.out[-1] == "\n" ? proc.out : proc.out + "\n"))
      
      if(proc.exitstatus.exitstatus != 0)
        raise JobError.new("Command failed:\n" + proc.strCmd + "\n" + o)
      else
        puts proc.strCmd
        print o
        true
      end
    end
    def track(proc)
      @procs << proc
    end
    def runcmd(cmd, redirect = nil)
      proc = spawn(cmd, redirect)
      begin
        wait
      end while(!proc.exited?)
      
      finish(proc)
    end
    
    def wait
      callcc { |c|
#        puts "#{@currentJob} wait"
        @currentJob.cont = c
        @enginecc.call
      }
    end
    
    def run(maxProcs = 0, keepGoing = false)
      begin
        @jobs = Set.new
        @procs = Set.new
        @notify = Set.new
        @npipe = IO.pipe
        
        Signal.trap("CHLD") {
          @npipe[1].write("x")
        }
        
        callcc { |c|
          @enginecc = c
        }
        @currentJob = nil
        
#        puts "ITERATION"
        
        # Run jobs
        while(true)
          begin
            sleep(0)
            @procs.each { |proc| proc.read }
            reapChilds
            
            if(!@notify.empty?)
              n = @notify.first
              @notify.delete(n)
              @currentJob = n
              
#              puts "Resuming job #{n}"
              n.cont.call
            elsif((@procs.size() < maxProcs) || maxProcs == 0)
#              puts "Using yield to get new job"
              @jobs << (@currentJob = Job.new)
#              puts "New job #{@currentJob}"
              if(!yield(self))
#                puts "No more jobs"
                if(@jobs.size() == 1)
#                  puts "Finished => return true" 
                  return true
                else
                  break
                end
              end
            else
#              puts "break runloop"
              break
            end
          rescue JobError => e
            puts e.to_s
            return false if(!keepGoing)
          ensure
            if(@currentJob != nil)
#              puts "Removing job #{@currentJob}"
              @jobs.delete(@currentJob)
              @currentJob = nil
            end
          end
        end
        
#        p @jobs
#        p @procs
        if(@jobs.empty? || @procs.empty?)
          raise "FAILD"
        end
        

        # Wait for I/O
#        puts "select"
        before = Time.now
        fds = @procs.map {|p| p.pipe }
        IO.select(fds + [@npipe [0]], nil, fds + [@npipe [0]], 1)
        delay = Time.now - before
#        puts "select took #{delay} time"
        
        begin
          begin
            r = @npipe[0].read_nonblock(8*1024).length
          end while r > 0
        rescue IO::WaitReadable
        end
  
        # Read stdout
#        puts "read"
        @procs.each { |proc| proc.read }
        
        reapChilds
        
#        puts "re-main-loop"
        @enginecc.call
      ensure
        @procs.each { |proc|
          begin
            Process.kill(9, proc.pid)
          rescue
          end
        }
        Signal.trap("CHLD", "SIG_IGN")
        @procs = nil
        @jobs = nil
        @enginecc = nil
        @currentJob = nil
        @notify = nil
        @npipe.each { |fd| fd.close }
        @npipe = nil
      end
    end
    private
    def reapChilds
      # Search completed processes, remove them from @procs, and add their jobs to @notify
      @procs.delete_if { |proc|
        r = Process.waitpid2(proc.pid, Process::WNOHANG)
        proc.exitstatus = if r != nil then r[1] else nil end
        if(proc.exited?)
#          puts "reaped #{proc.pid}, notifying #{proc.job}"
          @notify << proc.job
          true
        else
          false
        end
      }
      end
  end
end

