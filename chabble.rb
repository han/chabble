# encoding: UTF-8
#

require 'algorithms'

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


  include Containers

  def initialize
    @count = Hash.new(0)
    @word_set = Trie.new
    @row_points = []
    @col_points = []
    @rows = []
    @cols = []
    puts "reading word lists"
    read_word_list 'OpenTaal-210G-basis-gekeurd.txt'
    read_word_list 'OpenTaal-210G-flexievormen.txt'
    read_word_list 'tweedriewoorden.txt'
  end

  def read_board
    File.open('board.txt') do |f|
      row = 0
      while s = f.gets
        puts s
        s.chomp!
        @rows[row] = s
        col = 0
        s.each_char do |c|
          @count[c.to_sym] += 1 if ('a'..'z').include? c
          @count[:_] += 1 if ('A'..'Z').include? c
          (@cols[col] ||= '') << c
          col += 1
        end
        row += 1
      end
    end
    @hwords = word_map(@rows)
    @vwords = word_map(@cols)
    puts @rows.inspect
    puts @cols.inspect
    puts @hwords.inspect
    puts @hwords.inspect
  end

  def read_fields
    File.open('fields.txt') do |f|
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

  def word_map(lines)
    words = []
    lines.each_with_index do |s, i|
      words[i] = []
      start = -1
      word = ''
      in_word = false
      (s + '|').each_char.each_with_index do |c, j|
        if in_word
          if c == '.' || c == '|'
            words[i][start] = word
            words[i][j-1] = word
            in_word = false
          else
            word << c
          end
        else
          unless c == '.' || c == '|'
            in_word = true
            word = c
            start = j
          end
        end  
      end
    end
    words
  end

  def read_letters
    until @letters
      puts 'letters: (?: blank)'
      @letters = gets.chomp
      exit if @letters.length == 0
      @letters.downcase!
      @letters = nil unless @letters =~ /^[a-z?]+$/ && @letters.count('?') <= 2
    end
    @letters.each_char do |c|
      @count[c.to_sym] += 1 if ('a'..'z').include? c
      @count[:_] += 1 if c == '?'
    end
  end


  def read_word_list(f)
    File.open(f, 'r:utf-8') do |f|
      while !f.eof?
        s = f.readline 
        next unless s
        s = s.chomp.gsub(/[-']/,'').gsub(/ë/,'e').gsub(/é/,'e')
        next unless s.length > 3
        next unless s =~ /^[a-z]+$/
        next unless s[/[aeoiu]/]
        @word_set[s] = true
      end
    end
  end

  def preprocess(lines, words, point_map)
    pre = []
    pattern = ''
    lines.each_with_index do |s, i|
      pre[i] = []
      s.each_char.each_with_index do |c, j|
        next unless c == '.'
        if i > 0 && i < 14 && words[j][i-1] && words[j][i+1]
          pattern = "#{words[j][i-1]}#{c}#{words[j][i+1]}"
          start = j - words[j][i-1].length
        elsif i > 0 && words[j][i-1]
          pattern = "#{words[j][i-1]}#{c}"
          start = j - words[j][i-1].length
        elsif i < 14 && words[j][i+1]
          pattern = "#{c}#{words[j][i+1]}"
          start = j
        elsif point_map[i][j] == '*'
          s[j] = '*'
          next
        else
          next
        end
        permutations(@letters, pattern) do |p|
          if @word_set.has_key? p.downcase
            s[j] = '?'
            letter = p[pattern.index('.')]
            (pre[i][j] = {})[letter] =  {:word => p, :score => points(p, pattern, point_map[i][start, pattern.length])}
          end
        end
        s[j] = '!' if s[j] != '?'
      end
    end 
    #puts pre.inspect
    pre
  end


  def permutations(letters, pattern)
    n = pattern.count '.?*'
    return if n == 0
    letters.split('').permutation(n).each do |p|
      q = ''
      i = j = 0
      pattern.each_char do |c|
        if ".?*".include?(c)
          q << p[j].to_s
          j += 1
        else
          q << c
        end
      end

      yield q
      #if letters.include?('?')
        #qs = ('a'..'z').map {|c| q.sub(/\?/,c.upcase)}
      #else
        #qs = [q]
      #end

      #qs.each {|q| yield q}
    end
  end

  def points(q, pattern, points)
    sum = q.split('').each_with_index.map {|el, i| (LETTER_VALUES[el.to_sym] || 0) * ('.*?'.include?(pattern[i]) ? MULT[points[i]] : 1)}.inject {|el, s| s + el}
    pattern.each_char.each_with_index do |c, i|
      next unless '.*?'.include? c
      sum *= 2 if points[i] == '2'
      sum *= 3 if points[i] == '3'
    end
    sum += 40 if pattern.count('.') == 7
    sum
  end


  def print_board
    0.upto(14) do |i|
      r = ''
      0.upto(14) do |j|
        if @rows[i][j] == '!'  && @cols[j][i] == '!' 
          r << '+'
        elsif @rows[i][j] == '!'
          r << '-'
        elsif @cols[j][i] == '!'
          r << '|'
        elsif @rows[i][j] == '?' || @cols[j][i] == '?'
          r << '?'
        else
          r << @rows[i][j]
        end
      end
      puts r 
    end

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

        if ['.','?', '!', '*'].include?(s[start])
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
      w = p.downcase
      next unless w =~ /#{regex}/
      matches = if w['?']
        ww = w.gsub(/\?/,'.')
        puts "? => . #{ww}"
        @word_set.wildcard(ww)
      else
        @word_set[w] ? [w] : []
      end
      next if matches.count == 0

      puts "looked for #{w}"
      puts "found #{matches.inspect}"
      matches.each do |r|
        #puts "!found! #{w}"
        points = points(w, pattern, point_map[start, pattern.length])
        sum = 0
        pattern.each_char.each_with_index do |c, i|
          next unless c == '?'
          #puts "** #{sec[i+start].inspect}, #{p[i]}"
          sum += sec[i+start][w[i]][:score]
        end
        points += sum
        results["#{r} #{start}x#{line}"] = points
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

  def show(results)
    results.each_pair.sort_by {|k,v| v}.each do |r|
      puts "#{r[0]} - #{r[1]}"
    end
  end


  def run
    read_board
    read_fields
    read_letters
    LETTER_COUNT.each do |k, v|
      remaining = v - @count[k]
      puts "#{k}: #{remaining}" if remaining > 0
    end
    puts 'vom'
    @vom = preprocess @rows, @vwords, @col_points
    puts 'hom'
    @hom = preprocess @cols, @hwords, @row_points
    print_board
    puts "horizontal matches"
    show find_words(@rows, @hwords, @vom, @row_points)
    puts
    puts "vertical matches"
    show find_words(@cols, @vwords, @hom, @col_points)
  end

end

Chabble.new.run
