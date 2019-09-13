require_relative 'syllabicator.rb'
require "json"

# TAGALOG STEMMER
# This Tagalog stemmer is based on a third party paper
# by Mr. Don Erick Bonus found here: 
# https://www.academia.edu/1800061/A_Stemming_Algorithm_for_Tagalog_Words
# This Ruby implementation is written by LJ Sta. Ana

$out = File.open("out", "w:UTF-8")

class Stemmer 
    
    def initialize(syllabicator, options, wordlist)
        @syllabicator = syllabicator
        @options = options

        @verbose = false

        # hash dictioanry for speed 
        @words = {} 

        # cache fo speed
        @cache = {}

        wordlist.each do |word| 
            @words[word] = true
        end


        @prefixes = [
            "nakikipag", "pakikipag", "pinakama", 
            "pagpapa", "pakiki", "magpa",
            "napaka", "pinaka", "panganga",
            "nakapag", "tagapag", "pinag", 
            "pagka", "ipinag", "mapag",
            "mapa", "taga", "ipag", "makipag", 
            "nakipag", "tiga", "pala", "pina",
            "pang", "ipa", "nang", "naka",
            "pam", "pan", "pag", "mag", "nam",
            "nag", "man", "may", "ma", "na", "ni",
            "pa", "in", "ka", "um", "ibi"
        ]

        @suffixes = [
            "uhan", "han", "hin", "ing", 
            "ng", "an", "in", "n"
        ]

        @infixes = [
            "in", "um"
        ]
        
        @vowels = 
            treefy([
                "a", 
                "e", 
                "i", 
                "o", 
                "u"
            ])

        
        @clusters = 
            treefy([
            "bl", "br", 
            "dr", "dy",
            "gr",
            "kr", "ky",
            "pl", "pr",
            "sw",
            "tr", "ts",
            "sh"
        ])

        # checks if a word is already seen
        @seen = {}

        # apply circumfixation on prefixes
        apply_circumfixation
    end
    
    # hashmaps a consonant cluster for optimization (makes searching for)
    # a cluster a log(1) operation
    def treefy(array) 
        hash = {} 
        array.each do |val| 
            # lookup 
            lookup = hash
            # loop through the end
            val.length.times do |i|
                letter = val[i]

                if  i > val.length - 1 then 
                    break
                end

                role = {}
                if i ==  val.length - 1 then 
                    role = true
                end
                
                if !lookup[letter] then 
                    lookup[letter] = role
                end
                
               lookup = lookup[letter]
            end
            lookup = hash
        end
        hash
    end

    # returns the first consonant cluster that is matched by a word
    # with priority on longer clusters
    def tree_match(cluster, index, word)
        result = "" 
        lookup = cluster
        
        # get the piece of the word from index to the last leter
        string = word[index..-1]

        string.length.times do |i| 
            letter = string[i]
            # look for the current letter in the clusters
            lookup_t = lookup[letter]

            if lookup_t.class == Hash then 
                # if found then change lookup and add letter to buffer
                lookup = lookup_t
                result += letter
            elsif lookup_t == true then 
                # return the result 
                result += letter
                break
            else
                # if not found then quit and return not a cluster
                return false
            end
        end
        result
    end
    

    # syllabicator getter
    def syllabicator 
        @syllabicator
    end

    # output 
    def out(message)
        if @verbose then 
           return $out << (message)
        end
        nil
    end

    # letter type checker
    def is_vowel(letter) 
        @vowels[letter] == true
    end

    def is_consonant(letter)
       # if it's not a vowel and not nil
       # and the valid input is just lowercase
       # a-z, it can just be  dichotomy between 
       # a vowel and a consonant
       (!is_vowel(letter) && letter != nil)
    end

    # prefix circumfix
    # - applies circumfixation on a prefix 
    # - circumfixation is applied after the first consonant
    def circumfix_prefix(prefix)
        # add -in- and -um- after the 
        # first consonant of the word 
        letters = prefix.split("")
        buffer = ""
        letters.each_with_index do |letter, index|
            buffer += letter
            if is_consonant(letter) then 
                circumfixed_prefixes = []
                @infixes.each do |infix| 
                    tail = prefix[index+1..-1]
                    fix = buffer + infix + tail
                    circumfixed_prefixes.push(fix)
                end
                return circumfixed_prefixes
            end
        end
        false
    end

    # circumfix prefixes / apply circumfixation
    def apply_circumfixation
        circumfixes = []
        @prefixes.each do |prefix|
            circumfixes += circumfix_prefix(prefix)
        end
        @prefixes += circumfixes
    end

    # prefix matcher
    # - gets which prefixes a word matches
    def prefix_match(word)
        prefix_matches = [] 
        @prefixes.each do |prefix|
            # check if word matches prefix 
            word_part = word[0..prefix.length-1]
            if prefix == word_part then
                prefix_matches.push(prefix)
            end
        end
        prefix_matches
    end

    # suffix matcher
    # - gets which suffixes a word matches
    def suffix_match(word)
        suffix_matches = []
        @suffixes.each do |suffix| 
            # check if word matches suffix
            word_part = word[-suffix.length..-1]
            if suffix == word_part then 
                suffix_matches.push(suffix)
            end
        end
        suffix_matches
    end

    # infix matches 
    # - gets which infixes a word matches
    def infix_match(word)
        infix_matches = [] 
        @infixes.each do |infix| 
            # check if word has infix after the first consonant
            word_part = word.include?(infix)
            if word_part then 
                infix_matches.push(infix)
            end
        end
        infix_matches
    end

    # removes specific fixes from a word
    def remove_fixes(word, prefix, infix, suffix)

        if prefix != nil then 
            word = word.gsub(/^#{prefix}/, "")
        end

        if infix != nil then 
            word = word.gsub(/#{infix}/, "")
        end

        if suffix != nil then 
            word = word.gsub(/#{suffix}$/, "")
        end

        word
    end

    # gets the first consonant in the word (retuns index)
    def first_consonant(word) 
        word.length.times do |i| 
            letter = word[i] 
            if is_consonant(letter) then 
                return i
            end
        end
        nil
    end

    # gets the first vowel in the word (returns index)
    def first_vowel(word)
        word.length.times do |i| 
            letter = word[i]
            if is_vowel(letter) then 
                return i
            end
        end
        nil
    end

    # handles partial reduplication
    def handle_partial_reduplication(root, original)

   
        out  "\t" * 5 + "> Handling partial reduplication for #{root} over #{original}\n"
        original_syls = syllabicator.syllabicate(original)
        root_syls = syllabicator.syllabicate(root)
        no_dups = []

        if (root[0] == root[1])
            root_t = root.clone
            root_t[0] = ""
            no_dups.push(root_t)
        end        
     
        if root_syls.length >= 3 then 
            if (is_consonant(root[0]) && 
                is_vowel(root[1])) 
                root_t = root.dup
                root_t[0..1] = "" 
                no_dups.push(root_t)
            end
        end

        # "if the first syllable of the root has a cluster
        #  of consonants, two approaches can be used. This is
        #  based on the speaker's habit."
        cluster = tree_match(@clusters, 0, root)
       
        # approach 1: reduplicates the first consonant 
        # and the first vowel of the term
        first_cons = first_consonant(root)
        first_vow = first_vowel(root)
        if (first_vow - first_cons == 1 && 
            tree_match(@clusters, first_cons + 1, root))
            root_t = root.clone
            root_t[first_cons..first_vow] = "" 
            no_dups.push(root_t)
        end


        # approach 2: reduplicates the cluster of consonants
        # including the succeeding vowel of the stem
        if cluster then 
            root_t = root.clone
            root_t[0..cluster.length-1] = ""
            no_dups.push(root_t)
        end


        # in a three syllable root, the first two syllables
        # are reduplicated and hyphenated from the stme
        if root_syls.length == 5 then 
            first_two_syls = root_syls[0..1]
            root_t = root.dup
            root_t[0..first_two_syls.length-1] = "" 
            no_dups.push(root_t)
        end

        out  "\t" * 5 + "No duplicates: #{no_dups}\n"
        no_dups
    end

    # unassimilates a word by prefix 
    def prefix_unassimilate(word, prefix)

        out  "\t" * 4 + "> Unassimilating Word #{word} over #{prefix}-\n"
   

        # list of reversions of words
        word_reverts = []

        word_t = word.clone
        
        # D-R ASSIMILATION
        # dapat - marapat
        # change in d to r where in between two vowels 
        # VdV - VrV
        # happens in prefixing 
        # check if the word starts with `r`
        if word[0] == "r" then 
            out  "Handling D-R assimilation\n"
            # check if the last letter of the prefix is a vowel
            vowel_last = is_vowel(prefix[-1])
            # check if the second letter of the word is a vowel
            vowel_next = is_vowel(word_t[1])
            # if both are vowels then change r back to d
            if (vowel_last && vowel_next) then 
                word_reverts.push("d" + word_t[1..-1])
            end
        end

        # CUSTOM ASSIMILATION BY PREFIX
        word_t = word.clone
        starts_vowel = is_vowel(word_t[0])

        # for prefixes that ends in `m`
        if (prefix[-1] == "m" && starts_vowel) then 
            out  "\t" * 4 + 
                    "Prefix ends with `m` and word starts with vowel.\n" +
                    "\t" * 4 +"Unassimilating to b/p + word case. \n"
            # b case
            word_reverts.push("b" + word)
            # p case
            word_reverts.push("p" + word)

        # for prefixes that ends in `n`
        elsif (prefix[-1] == "n" && starts_vowel) then 
            out  "\t" * 4 + 
                    "Prefix ends with `n` and word starts with vowel.\n" + 
                    "\t" * 4 + "Handling d/l/s/t + word case \n"

            # d case
            word_reverts.push("d" + word) 
            # l case 
            word_reverts.push("l" + word)
            # s case 
            word_reverts.push("s" + word)
            # t case
            word_reverts.push("t" + word)


        # for prefixes that ends in `ng` 
        elsif (prefix[-1] == "ng" && starts_vowel) then
            out  "\t" * 4 + 
                    "Prefix ends with `g` and word starts with vowel." + 
                    "Handling k/null + word case \n"

            # get word's tail 
            tail = word_t[1..-1]
            # k case
            word_reverts.push("k" + word) 
            # null case
            word_reverts.push(tail)
        end

        out  "\t" * 4 + "Word Reverts: #{word_reverts}\n"

        word_reverts
    end

    # checks if a word has a vowel or not 
    def has_no_vowel(word) 
        word.length.times do |i| 
            letter = word[i]
            if is_vowel(letter) then 
                return false
            end
        end
        true
    end

    # checks if a word has a consonant or not 
    def has_no_consonant(word)
        word.length.times do |i| 
            letter = word[i]
            if is_consonant(letter) then 
                return false
            end
        end
        true
    end

    # unassimilates a word by suffix
    def suffix_unassimilate(word, suffix)
        
        out  "\t" * 4 + "> Unassimilating Word #{word} over -#{suffix}\n"
        word_reverts = []

        word_t = word.clone 

        # D-R ASSIMILATION
        # if suffix is either
        # -in or -an an and the word ends in r
        # unassimilate r to d
        if ((suffix == "in" || suffix == "an") && 
            (word_t[-1] == "r"))
            out  "\t" * 4 + "Handling D-R Assimilation\n"
            word_t[-1] = "d"
            if !@seen[word_t] then
                word_reverts.push(word_t)
            end
        end

        # O-U ASSIMILATION
        # if there is a suffix 
        # change the last u to an o
        out  "\t" * 4 + "Handling O-U assimilation\n" 
        word_t = word.clone
    
            word_t.length.times do |i| 
                idx = word.length - i - 1
                letter = word_t[idx]
                if letter == "u" then 
                    word_t[idx] = "o" 
                    if !@seen[word_t] then
                        word_reverts.push(word_t)
                    end
                    break
                end
            end

        # KAS-KS ASSIMILATION
        out  "\t" * 4 + "Handling KAS-KS assimilation\n" 
        word_t = word.clone
        word_t = word_t.reverse
        word_t = word_t.sub("sk", "sak")
        word_reverts.push(word_t.reverse)
        
        out  "\t" * 4 + "Word Reverts: #{word_reverts}\n"
        word_reverts 
    end

    # acceptability conditions for a candidate/form
    # as described in the paper
    def accept_state(candidate, original)
        out  "\t" * 4 + "> Checking accept state for stemmed #{candidate} for #{original}\n"
        state = true
        # "if the form starts with a vowel, then
        # at least three letters must remain after stemming
        # and at least one one of these must be a consonant"
        if is_vowel(original[0]) then 
            shorter_than_three = candidate.length < 3
            if (shorter_than_three || has_no_vowel(candidate)) then
                state = false
            end
            out  "\t" * 4 + "Starts with a vowel\n"
            out  "\t" * 4 + "REJECT CONDITIONS\n"
            out  "\t" * 4 + "shorter_than_three: #{shorter_than_three}\n"
            out  "\t" * 4 + "has_no_vowel: #{has_no_vowel(candidate)}\n"
        # "if the form starts with a consonant, then at least four 
        #  characters must remain after stemming and at least one 
        #  of these letters must be a vowel"
        else 
            shorter_than_four = candidate.length < 4
            if (shorter_than_four || has_no_consonant(candidate)) then 
                state = false
            end
            out  "\t" * 4 + "Starts with a consonant\n"
            out  "\t" * 4 + "REJECT CONDITIONS\n"
            out  "\t" * 4 + "shorter_than_four: #{shorter_than_four}\n"
            out  "\t" * 4 + "has_no_consonant: #{has_no_consonant(candidate)}\n"
        end
        out  "\t" * 4 + ":: State: #{state}\n"
        state
    end

    # handle full word reduplication 
    # full word reduplication 
    # sarisari gamugamo 
    # paruparo
    def handle_full_word_reduplication(word, original)
        no_dups = []
        
        # remove hyphens in the middle 
        word_t = word.gsub("-", "")

        # get the first and right half of the world
        word_left = word_t[0..word_t.length / 2 - 1] 
        word_right = word_t[word_t.length/2 + word_t.length - 1] 

        # handle assimilatory case
        if (word_left && word_right) then 
            if [word_left[-1] == "u" && word_right[-1] == "o"] then 
                word_left_t = word_left.clone 
                word_left_t[-1] = "o"
                word_left = word_left_t
            end

            # handle non-assimilatory case 
            if word_left == word_right then 
                if !@seen[word_left] then
                    no_dups.push(word_left)
                end
            end
        end

        no_dups
    end

    # filters a set of words by the accepted conditions only
    def accepts_only(candidates, original)
        final = []
        
        # handle partial reduplication
        candidates.each do |candidate| 
            candidates += handle_full_word_reduplication(candidate, original)
            candidates += handle_partial_reduplication(candidate, original)
        end

        candidates.each do |candidate| 
            # handle partial and full reduplication on candidate 
            accept = accept_state(candidate, original)
            if accept then 
                final.push(candidate)
            end
        end
        final
    end

    # unfixes a word
    def do_unfix(word, prefixes, infixes, suffixes)
        out  "\t\tunfix(#{word}, #{prefixes}, #{infixes}, #{suffixes})\n"

        # AFFIXES
        prefixes = prefixes + [nil]
        suffixes = suffixes + [nil]
        infixes = infixes + [nil]

        # CANDIDATES LIST
        candidates = []

        prefix_no = 0
      
        # remove all prefix, infix, and suffix combinations
        prefixes.each do |prefix| 
            infixes.each do |infix| 
                suffixes.each do |suffix| 
                    
                    out  "\t" * 2 + "prefix_no #{prefix_no}\n"
                    out  "\t" * 3 + "word_before: #{word}\n"
                    out  "\t" * 3 + "prefix_to_remove: #{prefix}\n"
                    out  "\t" * 3 + "infix_to_remove: #{infix}\n"
                    out  "\t" * 3 + "suffix_to_remove: #{suffix}\n"
                    
                    # remove current affixes from word
                    word_t = word.clone
                    word_t = remove_fixes(word_t, prefix, infix, suffix)
                   
                    out  "\t" * 3 + "word_after: #{word_t}\n"

                    # unassimilate word by prefix
                    if prefix then
                        reverts = prefix_unassimilate(word_t, prefix)
                        # add reverted words to candidates
                        candidates += reverts
                    end

                    # unassimilate word by suffix 
                    if suffix then 
                        reverts = suffix_unassimilate(word_t, suffix)
                        # add reverted words to candidatesd
                        candidates += reverts
                    end


                    # add word to candidates
                    candidates.push(word_t)
                  

                    prefix_no += 1
                end
            end
        end

        out  "\t" * 2 + "Tentative Candidates: #{candidates}\n"
        out  "\t" * 2 + "Filtering candidates using acceptability tests.\n"
        candidates = accepts_only(candidates, word)
        candidates = candidates.sort_by {|v| v.length}
        out  "\t" * 2 + "Final Candidates: #{candidates}\n"

        candidates.uniq
    end

    # stems a word
    def do_stem(word, prev_affixes) 
        
        # if a word has been seen already don't process it
        if @seen[word] then 
            return []
        else
            @seen[word] = true 
        end

        if @cache[word] then 
            return @cache[word]
        end

        prefix_matches = prefix_match(word)
        suffix_matches = suffix_match(word)
        infix_matches = infix_match(word)
        fix_nos = prefix_matches.length + 
                  infix_matches.length + 
                  suffix_matches.length

        cur_affixes = [prefix_matches, suffix_matches, infix_matches]

        if prev_affixes != cur_affixes then 
            out  "do_stem(#{word}):\n"
            out  "\tprefix_matches : #{prefix_matches}\n"
            out  "\tsuffix_matches : #{suffix_matches}\n"
            out  "\tinfix_matches  : #{infix_matches}\n"
            out  "\tfix_nos        : #{fix_nos}\n"

            candidates = 
                do_unfix(word, prefix_matches, infix_matches, suffix_matches)
            
            # CANDIDATES
            out  "CANDIDATES: #{candidates}\n"   
            candidates.each do |candidate| 
                candidates += do_stem(candidate, cur_affixes)
            end 
        

            out  "RESULT: #{candidates}\n" 
            candidates = candidates.uniq
            @cache[word] = candidates  
            return candidates
        end 
        
        []
    end

    # stemmer driver 
    def stem(word)  
        @seen = {}
        out  "Stemming Word `#{word}`\n"
        out  "===================================\n"
        @word = word
        
        word = word.gsub("-", "")
        results = do_stem(word, [])
    
        if word[0] == "i" then 
            results = do_stem(word[1..-1], []) + results
        end
        
        if (results.length == 1 && results[0] == word) then 
            results = handle_partial_reduplication(word)
        end

        out  "RESULTS: #{results}\n"

        # filter tagalog words only
        final_results = []
        aside = []
        results.each do |result| 
            # check if word is in dictionary 
            if @words[result] then 
                final_results.push(result)
            else 
                aside.push(result)
            end
        end
        final_results = final_results.sort_by {|v| v.length}
        final_results += aside

        out  "TAGALOG WORDS: #{final_results}\n"

        final_results
    end

    # validty test function - from a tsv file
    def validity_test(test_file, report_file)
        ifile = File.open(test_file, "r:UTF-8", &:read)
        ofile = File.open(report_file, "w:UTF-8")

        words = {} 

        ifile.split("\n")[1..-1].each do |line| 
            tokens = line.split(":")
            words[tokens[0].strip] = tokens[1].strip
        end
        
        ofile  "VALIDITY TEST (TAGALOG STEMMER) \n" 
        ofile  "================================================\n"

        # DISPLAY TEST WORDS
        ofile  "TEST WORDS (#{words.length} word/s)\n"
        i = 0
        words.each do |word, correct| 
            ofile  "##{i+1} Word: " + 
                        word.ljust(words.keys.collect{|v| v.length}.max) + " | "
            ofile  "Expected: " + 
                        correct.ljust(words.values.collect{|v| v.length}.max) 
            ofile  "\n"
            i += 1
        end

        # MAKE TESTS 
        results = {} 
        score = 0 
        total = words.length
        ofile  "\n"
        words.each do |word, correct| 
            result = stem(word)[0]
            if result == correct then 
                score += 1
            end
            results[word] = result
        end

        # GET RESULTS 
        accuracy = score * 1.0 /total 
        ofile  "\n"

        # DISPLAY RESULTS 
        ofile  "RESULTS (#{accuracy * 100} %, #{score} right, #{total-score} wrong)\n"
        i = 0
        
        words.each do |word, correct| 
            result = results[word]
            in_dict = @words[word]
            if !in_dict then 
                in_dict = false
            end

            ofile  "##{i+1} Word: " + 
                        word.ljust(words.keys.collect{|v| v.length}.max) + " | "
            ofile  "Expected: " + 
                        correct.ljust(words.values.collect{|v| v.length}.max) + " | "
            ofile  "Expected in Dictionary? " + 
                        in_dict.to_s + " | "
                
            ofile  "Prediction: " + 
                        result.ljust(results.values.collect{|v| v.length}.max)  + " | "
            if result == correct then 
                ofile  "CORRECT"
            else
                ofile  "WRONG" 
            end
            ofile  "\n"
            
            i += 1
        end
    end

        
    # speed test function - please enter a lot like more than 
    # 1000 words for more generalized results
    def speedtest
        ifile = File.open("wordlist", "r:UTF-8", &:read)
        words = ifile.split("\n")

        puts  "No display output, plain storage"
        start_time = Time.now.to_i
        store = {}
        i = 0
        stem_count = 0
        words.each do |word|
        
            begin
                word = word.downcase
                stemmed = stem(word)
                store[word] = stemmed[0]
                print "Stem Count: #{stem_count} Cache Count: #{@cache.keys.length} Word: #{i}/#{words.length} #{word}  #{stemmed[0]}                                           \r"
                stem_count += 1
            rescue
                store[word] = word
            end 
            $stdout.flush 
            i += 1
        end
        end_time = Time.now.to_i
        puts "Start time: " + start_time.to_s
        puts "End time: " + end_time.to_s
        puts "Total time: " + (end_time - start_time).to_s + " seconds"
        puts "Total No. of Words: " + (words.length).to_s + " words"

        $out << JSON.pretty_generate(store)
    end
end


options = {            # default mode - up mode (can be overriden)
    :verbose => false  # log output explanations
}
wordlist = File.open("wordlist", "r:UTF-8", &:read).split("\n")
syllabicator = Syllabicator.new options
stemmer = Stemmer.new syllabicator, options, wordlist

# stemmer.validity_test("test_words.txt", "results.txt")


stemmer.speedtest