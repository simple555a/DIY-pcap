require 'drb'
module DIY
  class Builder
    def initialize(server = false, &block)
      @strategies = []
      instance_eval(&block)
      @server = server
    end
    
    def use(what)
      @strategies.unshift(what)
    end
    
    def before_send(arg= nil, &block)
      if arg
        @before_send_hook = arg
      else
        @before_send_hook = block
      end
    end
    
    def find_worker_keepers
      @curi ||= "druby://localhost:7878"
      @suri ||= "druby://localhost:7879"
      @me  ||= "druby://localhost:7880"
      # controller drb server
      DRb.start_service(@me)
      # client and server drb server
      @client = DRbObject.new_with_uri(@curi)
      @server = DRbObject.new_with_uri(@suri)
    end
    
    def client(ip_or_iport)
      @curi = ip_or_iport_with_default(ip_or_iport, 7878)
    end
    
    def server(ip_or_iport)
      @suri = ip_or_iport_with_default(ip_or_iport, 7879)
    end
    
    def me(ip_or_iport)
      @me = ip_or_iport_with_default(ip_or_iport, 7880)
    end
    alias controller me
    
    def ip_or_iport_with_default(ip_or_iport, default_port)
      default_port = default_port.to_s
      if ! ip_or_iport.include?(':')
        iport = ip_or_iport + ':' + default_port
      else
        iport = ip_or_iport
      end
      ip2druby(iport)      
    end
    
    def ip2druby(ip)
      if ! ip.include?('://')
        return "druby://" + ip
      end
      return ip
    end
    
    def pcapfile(pcaps)
      DIY::Logger.info( "Initialize Offline: #{pcaps.to_a.join(', ')}" )
      @offline = DIY::Offline.new(pcaps)
    end
    alias pcapfiles pcapfile
    
    def run
      @offline ||= DIY::Offline.new('pcaps/example.pcap')
      @strategy_builder = DIY::StrategyBuilder.new
      @strategies.each { |builder| @strategy_builder.add(builder) }
      find_worker_keepers
      controller = Controller.new( @client, @server, @offline, @strategy_builder )
      controller.before_send(&@before_send_hook)
      controller.run
    end
    
  end
end