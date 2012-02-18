# encoding: UTF-8

require 'bundler/setup'
require 'trie'
require 'benchmark'
require 'colored'
require 'readline'

class Chabble
  LETTER_COUNT = {
    a: 7, b: 2, c: 2, d: 5, e: 18, f: 2, g: 3, h: 2, i: 4, j: 2, k: 3, l: 3, m: 3,
    n: 11, o: 6, p: 2, q: 1, r: 5, s: 5, t: 5, u: 3, v: 2, w: 2, x: 1, y: 1, z: 2, _: 2
  }

  MULT = Hash.new(1).merge({
    '.' => 1,
    'D' => 2,
    'T' => 3
  })

  LETTER_VALUES = Hash.new(0).merge({
    a: 1, b: 4, c: 5, d: 2, e: 1, f: 4, g: 3, h: 4, i: 2, j: 4, k: 3, l: 3, m: 3,
    n: 1, o: 1, p: 4, q: 10, r: 2, s: 2, t: 2, u: 2, v: 4, w: 5, x: 8, y: 8, z: 5
  })



  def initialize
    @count = Hash.new(0)
    @word_set = Trie.new
    @row_points = []
    @col_points = []
    @rows = []
    @cols = []
    puts 'reading word lists'
    read_word_list 'OpenTaal-210G-basis-gekeurd.txt'
    read_word_list 'OpenTaal-210G-flexievormen.txt'
    read_word_list 'tweedriewoorden.txt', 2
  end

  def read_board_position(filename = 'board.txt')
    puts "Reading board from '#{filename}'"
    File.open(filename) do |f|
      row = 0
      while s = f.gets
        puts s
        s.chomp!
        @rows[row] = s
        col = 0
        s.each_char do |c|
          (@cols[col] ||= '') << c
          col += 1
        end
        row += 1
      end
    end
    count_letters
    @hwords = word_map(@rows)
    @vwords = word_map(@cols)
  end

  def count_letters
    ('a'..'z').each do |c|
      @count[c.to_sym] = @rows.inject(0) {|sum, r| sum + r.count(c) }
    end
    @count[:_] = @rows.inject(0) {|sum, r| sum + r.count('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}
  end

  def read_board_layout(filename = 'fields.txt')
    File.open(filename) do |f|
      row = 0
      while s = f.gets
        s.chomp!
        @row_points[row] = s
        col = 0
        s.each_char.each_with_index do |c, col|
          (@col_points[col] ||= '') << c
          col += 1
        end
        row += 1
      end
    end
  end

  # array of words per line. Word is stored at start and end position
  def word_map(lines)
    words = []
    lines.each_with_index do |s, i|
      words[i] = []
      start = -1
      word = ''
      in_word = false
      (s + '|').each_char.each_with_index do |c, j|
        if in_word
          if '.?!*|'.include?(c)
            words[i][start] = word
            words[i][j-1] = word
            in_word = false
          else
            word << c
          end
        else
          unless '.?!*|'.include?(c)
            in_word = true
            word = c
            start = j
          end
        end
      end
    end
    words
  end

  def letters(input)
    @letters = input.chomp
    return if @letters.length == 0
    @letters.downcase!
    @letters = nil unless @letters =~ /^[a-z_]+$/ && @letters.count('_') <= 2
  end


  def read_word_list(f, min_length = 4)
    File.open(f, 'r:utf-8') do |f|
      while !f.eof?
        s = f.readline
        next unless s
        s = s.chomp.gsub(/[-']/,'').gsub(/ë/,'e').gsub(/é/,'e')
        next unless s =~ /^[a-z]+$/
        next unless s.length >= min_length
        next unless s[/[aeoiu]/]
        @word_set.add s, true
      end
    end
  end

  # preprocess board to mark open tiles in the opposite direction as
  # free, restricted or blocked
  def preprocess(lines, words, point_map)
    pre = []
    pattern = ''
    lines.each_with_index do |s, i|
      pre[i] = []
      s.each_char.each_with_index do |c, j|
        next unless '.?!*'.include?(c)
        s[j] = '.'
        if i > 0 && i < 14 && words[j][i-1] && words[j][i+1]
          pattern = "#{words[j][i-1]}.#{words[j][i+1]}"
          start = i - words[j][i-1].length
        elsif i > 0 && words[j][i-1]
          pattern = "#{words[j][i-1]}."
          start = i - words[j][i-1].length
        elsif i < 14 && words[j][i+1]
          pattern = ".#{words[j][i+1]}"
          start = i
        elsif point_map[i][j] == '*'
          s[j] = '*'
          next
        else
          next
        end
        permutations(@letters, pattern) do |p|
          #puts "perm: #{p}, pattern: #{pattern}"
          if @word_set.has_key? p.downcase
            s[j] = '?'
            letter = p[pattern.index('.')]
            #puts "point map #{point_map[j]}, start: #{start}"
            (pre[i][j] ||= {})[letter] =  {:word => p, :score => points(p, pattern, point_map[j][start, pattern.length])}
          end
        end
        s[j] = '!' if s[j] != '?'
      end
    end
    #puts pre.inspect
    pre
  end


  def permutations(letters, pattern, &block)
    if pattern[/[.*?]/] == nil
      #puts "yielding #{pattern}"
      yield pattern
    else
      #puts "permute pattern: #{pattern}, letters: #{letters}"
      word_start = pattern.split(/[.?*]/,2)[0]
      node = @word_set.root
      word_start.downcase.each_char do |c|
        node = node.walk!(c)
        return if node == nil
      end
      letters.each_char.each_with_index do |c, i|
        t = letters.clone
        t[i] = ''
        if c == '_'
          ('a'..'z').each do |rc|
            permutations(t, pattern.sub(/[.?*]/,rc.upcase), &block)
          end
        else
          permutations(t, pattern.sub(/[.?*]/,c), &block)
        end
      end
    end
  end

  def points(q, pattern, points)
    #puts "q: #{q}, pattern: #{pattern}, points: #{points}"
    sum = q.split('').each_with_index.map {|el, i| (LETTER_VALUES[el.to_sym] || 0) * ('.*?'.include?(pattern[i]) ? MULT[points[i]] : 1)}.inject {|el, s| s + el}
    pattern.each_char.each_with_index do |c, i|
      next unless '.*?'.include? c
      sum *= 2 if points[i] == '2'
      sum *= 3 if points[i] == '3'
    end
    sum += 40 if pattern.count('.*?') == 7
    sum
  end


  def print_board(new_word = nil)

    if new_word
      puts
      puts "Candidate: '#{new_word[:s]}' for #{new_word[:p]} points at (#{new_word[:x]+1},#{new_word[:y]+1}) #{new_word[:d] == :h ? 'horizontal' : 'vertical'}"
      puts
    end

    0.upto(14) do |i|
      r = ''
      0.upto(14) do |j|
        strong = false
        if @rows[i][j] == '!'  && @cols[j][i] == '!' 
          c = '+'
        elsif @rows[i][j] == '!'
          c = '-'
        elsif @cols[j][i] == '!'
          c = '|'
        elsif @rows[i][j] == '?' || @cols[j][i] == '?'
          c = '?'
        else
          c = @rows[i][j]
        end
        if ('a'..'z').include?(c.downcase)
          fore = 'black'
          back = 'white'
        else
          back = case @row_points[i][j]
                 when 'D' then 'green'
                 when 'T' then 'blue'
                 when '2' then 'magenta'
                 when '3' then 'red'
                 else 'black'
                 end
          fore = 'white'
        end
        if '+-|?.*'.include?(c) && new_word
          s,d,x,y = new_word[:s], new_word[:d], new_word[:x], new_word[:y]
          if d == :h && y == i && (x...(x+s.length)).include?(j)
            c = s[j - x]
            fore = back == 'black' ? 'black' : 'white'
            back = 'yellow' if back == 'black'
            strong = true unless back == 'yellow'
          elsif d == :v && x == j && (y...(y+s.length)).include?(i)
            c = s[i - y]
            fore = back == 'black' ? 'black' : 'white'
            back = 'yellow' if back == 'black'
            strong = true unless back == 'yellow'
          end
        end
        c = c.send("#{fore}_on_#{back}".to_sym)
        c = c.send(:bold) if strong
        r << c
      end
      puts r
    end
    puts
  end

  #start with longest pattern until block
  #identify restricted fields
  #

  def find_words(lines, words, sec, point_map)
    found = {}
    max = @letters.length
    lines.each_with_index do |s, i|
      start = 0
      while start < 15
        pattern = ''
        match_regex = ''
        j = start
        while j <= 14 do
          break if s[j] == '!'
          #puts "** #{i},#{j}"
          match_regex << (s[j] == '?' ? "(#{sec[i][j].keys.join('|')})" : (s[j] == '*' ? '.' : s[j]))
          pattern << s[j]
          break if pattern.count(".?") >= max
          j += 1
        end
        if j && j < 14 && s[j] != '!' && words[i][j+1]
          pattern += words[i][j+1]
          match_regex += words[i][j+1]
        end


        #puts "regex: #{match_regex}"
        found.merge!(match(pattern, start, i, words[i], sec[i], point_map[i], match_regex)) unless pattern == ''

        if '.?!*'.include?(s[start])
          start += 1
        else
          start += words[i][start].length + 1
        end

      end
    end
    #puts "found: #{found.inspect}"
    found
  end


  def match(pattern, start, line, words, sec, point_map, regex, letters = @letters, results = {}, matched = {})
    return results unless pattern =~ /[a-z?*]/ && pattern =~ /[.?]/
    #puts "testing pattern: #{pattern}"
    matched[pattern] = true

    permutations(letters, pattern) do |p|
      #puts "#{p} in word_set? #{@word_set.has_key?(p.downcase) ? 'true' : 'false'}"
      if p.downcase =~ /#{regex}/ && @word_set.has_key?(p.downcase)
        #puts "!found! #{p}"
        points = points(p, pattern, point_map[start, pattern.length])
        sum = 0
        pattern.each_char.each_with_index do |c, i|
          next unless c == '?'
          sum += sec[i+start][p[i].downcase][:score]
        end
        points += sum
        results["#{p} #{start}x#{line}"] = points
      end
    end

    if words[start+pattern.length-1] != nil
      word_length = words[start+pattern.length-1].length
      pattern = pattern[0..-(word_length+1)]
      regex = regex[0..-(word_length+1)]
    end
    pattern = pattern[0..-2]
    if regex[-1,1] == ')'
      regex = regex.sub(/(.*)\(.*\)/, '\1') 
    else
      regex = regex[0..-2]
    end
    #puts "regex (in match) #{regex}"

    match(pattern, start, line, words, sec, point_map, regex, letters, results, matched) if pattern =~ /[.?]/

    results
  end

  def show(results, num = 10)
    results.each_pair.sort_by {|k,v| v}.last(num).each_with_index do |r, i|
      puts "#{num-i}: #{r[0]} - #{r[1]}"
    end
  end

  def candidate(dir, pos)

  end

  def show_remaining_letters
    LETTER_COUNT.each do |k, v|
      remaining = v - @count[k] - @letters.count(k.to_s)
      puts "#{k}: #{remaining}" if remaining > 0
    end
  end

  def find
    @vom = preprocess @rows, @vwords, @col_points
    @hom = preprocess @cols, @hwords, @row_points
    h, v = nil, nil
    time = Benchmark.measure do
      puts "horizontal matches"
      h = show find_words(@rows, @hwords, @vom, @row_points)
      puts
      puts "vertical matches"
      v = show find_words(@cols, @vwords, @hom, @col_points)
    end
    {:h => h, :v => v}
  end

  def hiscore(results)
    h = results[:h]
    v = results[:v]
    hiword = if h[-1][1] > v[-1][1]
      s, xy = h[-1][0].split(' ')
      x,y = xy.split('x').map &:to_i
      {x:x, y:y, s:s, d: :h, p: h[-1][1]}
    else
      s, yx = v[-1][0].split(' ')
      y,x = yx.split('x').map &:to_i
      {x:x, y:y, s:s, d: :v, p: v[-1][1]}
    end
    hiword
  end

  def get_word(results, cmd, pos)
    dir = cmd.to_sym
    top_list = results[cmd.to_sym]
    return nil unless top_list
    w = top_list[-pos.to_i]
    return nil unless w

    s, xy = w[0].split(' ')
    x,y = xy.split('x').map &:to_i
    y,x = x,y if dir == :v
    res = {x:x, y:y, s:s, d: dir, p: w[1]}
    #res
  end

  def add_word(word)
    par, ort = (word[:d] == :h ? [@rows, @cols] : [@cols, @rows])
    x, y = (word[:d] == :h ? [word[:x], word[:y]] : [word[:y], word[:x]])
    word[:s].each_char.each_with_index do |c, i|
      par[y][x+i] = c if '.*?!'.include?(par[y][x+i])
      ort[x+i][y] = c if '.*?!'.include?(ort[x+i][y])
    end
    @hwords = word_map(@rows)
    @vwords = word_map(@cols)
    count_letters
  end

  def help
    puts 'b, board <file>: load a new board'
    puts '[l, letters] <letters>: your letters (_ means blank)'
    puts 'v<num>, h<num>: show a found word on the board'
    puts 'a, add: add the currently shown word to the board'
    puts 'x, exit, q, quit: exit chabble'
  end

  def run
    read_board_position
    read_board_layout
    help

    cmd = ''
    cur_word = nil
    found_words = {}
    loop do
      input = Readline::readline('chabble>')
      cmd, args = input.split(/\s+/,2)
      Readline::HISTORY.push "#{cmd} #{args}"
      case cmd
      when 'b', 'board'
        found_words = {}
        read_board_position args || 'board.txt'
      when 'l', 'letters'
        letters(args)
        show_remaining_letters
        found_words = find
        cur_word = hiscore(found_words)
        print_board(cur_word)
      when 'v', 'h'
      when /^(v|h)\s*([1-9]|10)$/
        cur_word = get_word(found_words, $1, $2)
        print_board(cur_word)
      when 'a', 'add'
        add_word(cur_word) if cur_word
        print_board
        found_words = {}
      when '?', 'h', 'help'
        help
      when 'exit', 'x', 'quit', 'q'
        break
      when /^[a-zA-Z_]{1,7}$/
        letters(cmd)
        show_remaining_letters
        found_words = find
        cur_word = hiscore(found_words)
        print_board(cur_word)
      else
        puts "Sorry, what??"
      end

    end
    puts 'Bye!'
  end

end

Chabble.new.run
