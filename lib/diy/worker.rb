# encoding : utf-8
require 'diy/packet'
require 'drb'
require 'thread'

module DIY
  class Worker
    
    include DRbUndumped
    
    def initialize(live)
      @live = live
      @recv_t = nil
      @start = false
      @queue = Queue.new
      @running = false
      loop_recv
      loop_callback
    end
  
    # 发包
    def inject(pkts)
      pkts.each do |pkt|
        DIY::Logger.info "send pkt: #{pkt.pretty_print}"
        @live.send_packet(pkt.content)
      end
    end
    
    def loop_recv
      @recv_t = Thread.new do
        DIY::Logger.info "start thread recving pkt..."
        @live.loop do |this, pkt|
          next unless @start
          @queue.push(pkt.body)
        end
        DIY::Logger.debug "worker: stopped loop recv"
      end
    end
    
    def loop_callback
      @running = true
      @callback_t = Thread.new do 
        #~ DIY::Logger.info "start thread callbacking pkt..."
        while @running do
          begin
            pkt = @queue.pop
            #~ DIY::Logger.info "callback: #{pkt}"
            @block.call(pkt) if @start and @block
          rescue DRb::DRbConnError
            DIY::Logger.info "closed connection by controller"
            @start = false
            @queue.clear
          rescue RangeError=>e
            DIY::Utils.print_backtrace(e)
            raise e
          end
        end
        DIY::Logger.debug "stopped loop callback"
      end
    end
    
    #收包
    def ready(&block)
      @start = false
      DIY::Logger.info("start recv pkt")
      @block = block
      @queue.clear
      @start = true
    end
    
    # 停止收发
    def terminal
      DIY::Logger.info("stop recv pkt")
      @start = false
      @queue.clear
    end
    
    # 停止线程
    def stop
      @running = false
      @queue.push nil
      @live.break
      Utils.wait_until { @recv_t && ! @recv_t.alive? }
      Utils.wait_until { @callback_t && ! @callback_t.alive? }    
    end
    
    # 过滤器
    def filter(reg)
      @live.set_filter(reg)
    end
    
    def inspect
      "<Worker: #{@live.net}>"
    end
  
  end
end