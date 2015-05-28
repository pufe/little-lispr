class Context
  def initialize(outer=nil, names=[], params=[])
    @outer = outer
    @dict = Hash[names.zip(params)]
  end
  def find(var)
    return @dict[var] if @dict[var]
    return @outer.find(var) if @outer
    return nil
  end
  def set(var, val)
    @dict[var]=val if @dict[var]
    @outer.set(var, val) if @outer
  end
  def define(var, val)
    @dict[var]=val
  end
end

class Interpreter
  class << self
    def main
      context = Context.new
      build_default(context)
      @running = true
      while @running
        begin
          puts format_sexp(eval_sexp(read_sexp, context))
        rescue => e
          puts e
          puts e.backtrace.join("\n")
          next
        end
      end
    end
    def build_default(context)
      {
        :nil => nil,
        :+ => ->(*args) { args.inject(:+) },
        :- => ->(*args) { args.inject(:-) },
        :* => ->(*args) { args.inject(:*) },
        :/ => ->(*args) { args.inject(:/) },
        :print => ->(*args) { puts(args) }
      }.each do |key, value|
        context.define(key, value)
      end
    end
    def special
      @special ||= {
        quote: ->(context, arg) {arg},
        define: ->(context, key, value) {
          context.define(key, eval_sexp(value, context))
          key
        },
        set: ->(context, key, value) {
          context.set(key, eval_sexp(value, context))
          key
        },
        lambda: ->(context, arglist, body) {
          ->(*args) { eval_sexp(body, Context.new(context, arglist, args)) }
        },
        quit: ->(context, *rest) {
          @running = false
          nil
        }
      }
    end
    def format_sexp(val)
      return '()' if val.nil?
      return val.inspect if val.class == String
      return val.to_s if val.class != Array
      "(#{val.map(&method(:format_sexp)).join(' ')})"
    end
    def eval_sexp(sexp, context)
      return nil if sexp == []
      return context.find(sexp) if sexp.class == Symbol
      return sexp if sexp.class == Fixnum
      return sexp if sexp.class == String
      if sexp.class == Array
        if special[sexp[0]]
          return special[sexp[0]].call(context, *sexp[1..-1])
        else
          return eval_sexp(sexp[0],context).call(*sexp[1..-1].map do |i|
                                                   eval_sexp(i, context)
                                                 end)
        end
      end
      return nil
    end
    def read_sexp
      print "lispr> "
      line = gets.chomp
      while(!balanced(line))
        print "lispr* "
        line += ' '+gets.chomp
      end
      parse_sexp(line)
    end
    def balanced(line)
      count = 0
      inside = false
      line.each_char do |c|
        case c
        when '('
          count+=1 if !inside
        when ')'
          count-=1 if !inside
        when '"'
          inside = !inside
        end
        if count<0
          raise "Unexpected ')'"
        end
      end
      count==0 && !inside
    end
    def parse_sexp(line)
      case line[0]
      when ' '
        line[0]=""
        return parse_sexp(line)
      when '('
        line[0]=""
        ans = []
        while line[0]!= ')'
          line[0] = "" while line[0]==' '
          ans << parse_sexp(line) unless line[0]==')'
        end
        line[0]=""
        return ans
      when '\''
        line[0]=""
        return [:quote, parse_sexp(line)]
      when '"'
        ans = line[/"[^"]*"/]
        line[/"[^"]*"/]=""
        return ans[1..-2]
      when /[0-9]/
        ans = line[/[0-9]+/]
        line[/[0-9]+/]=""
        return ans.to_i
      else
        ans = line[/[^) ]+/]
        line[/[^) ]+/]=""
        return ans.to_sym
      end
    end
  end
end

Interpreter.main
