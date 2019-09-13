require 'uea-stemmer'

stemmer = UEAStemmer.new 

words = File.open("en_wordlist", "r:UTF-8", &:read).split("\n")

i = 0
words.each do |word| 
    puts "Word #{i} of #{words.length}"
    stem = stemmer.stem(word)
    puts "#{word} --> #{stem}"
    i += 1
end