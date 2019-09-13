require 'json'

# FILIPINO SYLLABICATOR
# Ortograpiyang Filipino Tested
# Based on this paper: 
# https://samutsamot.files.wordpress.com/2016/06/syllabication-of-filipino-words.pdf
# Rules stipulated in the Ortograpiyang Pambansa 
# Implemented in the Ruby programming language by LJ Sta. Ana



class Syllabicator
    
    def initialize(config)
        @verbose = config[:verbose]
        
        # 1 - Ortograpiyang Filipino, 2 - UP Diksiyonaryong Tagalog 
        @mode    = config[:mode]
        
        # buffer & syllables  
        @cache = {}
        @buffer = ""
        @syllables = []
        @word = ""
        
        # cluster definitions (as defined in page 4-5)
        # - arranged in alphabetical order (may not be complete)
        # the purpose of this is to minimize the use of regular expressions
        # to a very specific case use case scenario where we can get the
        # first matched item in a tree given a string in O(x) time 
        # where x is the number of matched item without the need for
        # a buffer
        # tree_match(@clusters, "train") = "tr" 

        @clusters = treefy([
            "bl", "br", 
            "dr", "dy",
            "gr",
            "kr", "ky",
            "pl", "pr",
            "sw",
            "tr", "ts",
            "sh"
        ])

      

        @vowels = treefy(["a", "e", "i", "o", "u"])
    end
    
    # helper functions for printing 
    def print_verbose(text="")
        if @verbose then 
            print_verbose text 
        else 
            return nil
        end
    end

    def puts_verbose(text="")
        if @verbose then 
            puts_verbose text 
        else 
            return nil
        end
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
    def tree_match(cluster, index)
        result = "" 
        lookup = cluster
        
        # get the piece of the word from index to the last leter
        string = @word[index..-1]

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
    
    # defines the version used by the syllabicator
    def mode= (val)
        mode = val
    end
    
    def mode
        @mode  
    end
    
    # defines is tracing is enabled
    def verbose= (val) 
       @verbose = val  
    end
    
    def verbose 
       @verbose
    end
    
    # ------------ IMPLEMENTATION FUNCTIONS ------------ #
    
    # handles rules for the first letter in two modes which are actually
    # the same which is to check if a beginning letter is part of a consonant 
    # cluster, if it is it forms a part of the first syllable
    def start
        next_index = 0
        # check if a cluster 
        cluster = tree_match(@clusters, next_index)
        # if a cluster then add the current cluster to the current @buffer
        if cluster then 
            puts_verbose "Cluster start"
            @buffer += cluster
            next_index = cluster.length
        # el\se, apply operations for normal vowels and consonants 
        else
            print_verbose "0\n"
            print_verbose "\tBEFORE | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
            next_index = vowels_and_consonants(next_index)
            print_verbose "\tAFTER  | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
        end 
        # start operation on the second letter 
        # depending on mode

   
        op_flow(next_index) 
        

        # if last "syllable" is a sole consonant on > 2 syllables merge it with the 
        # the **last** syllable 
        if (is_consonant(@syllables[-1]) && 
            @syllables.length > 1 &&
            @syllables[-1].length == 1) then 
            @syllables[-2] = @syllables[-2] + @syllables[-1]
            @syllables.delete_at(-1)
        end

    end

    # flow mode 1 OP mode 
    def op_flow(index)
        next_index = index

        while next_index < @word.length
            print_verbose next_index.to_s + "\n"
            print_verbose "\tBEFORE  | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
            next_index = vowels_and_consonants(next_index)
            print_verbose "\tAFTER  | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
        end
        # push whatever is left of buffer to syllable 
        print_verbose "FINAL " + "\n"
        print_verbose "\tBEFORE | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
        integrate_buffer
        print_verbose "\tAFTER  | " + @buffer.to_s + " | " + @syllables.join("-") + "\n"
        puts_verbose
    end


    def are_letters_next(index, letters)
        endd = index + letters.length
        if endd < @word.length then 
            if @word[index..endd-1] == letters then 
                puts_verbose "true"
                return true 
            else 
                puts_verbose "false"
                return false
            end
        else 
            puts_verbose "false"
            return false
        end 
    end

    def validate_special_after_vowel(index,letters)
        length = letters.length
        (is_vowel(@word[index-1]) && are_letters_next(index, letters) &&
         (is_consonant(@word[index + length]) || 
         @word[index + length] == nil))
    end


    # rule 1: consonant and vowels (general rules)
    def vowels_and_consonants(index)

        puts_verbose "\tvowels_and_consonants(#{@word[index]})"
        # goto index 
        goto_index = index

        # get the current letter
        letter = @word[index]

     

        # if vowel apply either of 2 different rules
        if is_vowel(index) then 
            last_special_rules(index)

            puts_verbose "\t#{letter} is vowel"

            # if buffer and the last character
            # is a consonant 
            # pending syllable (buffer)
            if @buffer != ""  then 
                if is_vowel(@buffer[-1]) then
                    integrate_buffer
                    @buffer = letter
                else 
                    @buffer += letter 
                end
            # else if buffer is not empty, the current letter belongs to 
            # its own syllable as a vowel
            else 
                @buffer += letter
            end 

            goto_index += 1


        # else, if consonant check for number of consonants in right first
        # the maximum in the rulebook is four so we can define a loop that
        # only has a range up to four
        else
            
            # if last letter, add to previous syllable
            if index == @word.length - 1 then 
                @buffer += letter  
                return index + 1
            end

            puts_verbose tree_match(@clusters, 0) == nil  

            # SPECIAL CASES
            # [vowel]SK cases - e.g. disk, isk|rin, bisk|wit
            if validate_special_after_vowel(index, "sk") then 
                @buffer += "sk" 
                integrate_buffer 
                @buffer = ""
                return index + 2
            end

            # [vowel]ST cases - e.g. dist|ro, bist|ro, re|hist|tro
            if validate_special_after_vowel(index, "st") then 
                @buffer += "st" 
                integrate_buffer 
                @buffer = ""
                return index + 2
            end


            # [vowel]NST cases - e.g. dist|ro, bist|ro, re|hist|tro
            if validate_special_after_vowel(index, "nst") then 
                @buffer += "nst" 
                integrate_buffer 
                @buffer = ""
                return index + 3
            end

            # [vowel]MPR cases - e.g. imp|renta | imp|rompto
            if (validate_special_after_vowel(index, "mp") && 
                @word[index+2] == "r") then
                @buffer += "mp" 
                integrate_buffer 
                @buffer = ""
                return index + 2
            end

        

            puts_verbose "\t#{letter} is consonant"

            count = 0
            4.times.each do |i|
                look_at = i + index
                letter = @word[look_at]
                if !letter.nil? then 
                    if is_consonant(look_at) then
                        count += 1
                    else 
                        break
                    end
                end
            end

            puts_verbose "\trunning_consonant_count: #{count}"


            # apply rules depending on count 
            form = @word[index..index+count]
         
            # if only one consonant the letter is part of a new syllable 
            if count == 1 then 
                integrate_buffer
                @buffer = form[0]

            # if two consonants, the first letter belongs to the first
            # syllable while the second letter belongs to the second syllable 
            elsif count == 2 then
                @buffer += form[0] 
                integrate_buffer
                @buffer = form[1]

            # if three consonants, two rules can happen
            elsif count == 3 then 

                # if a first letter is m or n, check if the 
                # two other consonants is a cluster, if
                # yes add the first letter
                # in the form and integrate the current buffer
                # and the form a new syllable with the cluster 
                if ((form[0] == "m" || form[0] == "n" || form[0] == "s") &&
                    tree_match(@clusters, index + 1)) then
                    @buffer += form[0]
                    integrate_buffer
                    @buffer = form[1] + form[2]
                else
                # else, apply standard rules that say 
                # the first two consonants belong to the
                # one syllable while the other two
                # belongs to another 
                    @buffer += form[0] + form[1]
                    integrate_buffer 
                    @buffer = form[2]
                end

            # if there are four words, then the rules in the paper
            # says that the first two letters are in one syllable
            # while the other two are in another
            elsif count == 4 then 
                @buffer += form[0] + form[1]
                integrate_buffer
                @buffer = form[2] + form[3]
            end

            goto_index += count
           
        end

        return goto_index
    end

    # special rules for the last letter 
    def last_special_rules(index)
        letter = @word[index]
        # if last letter apply special rules to consonants
        if (index == @word.length - 1 && is_consonant(letter)) then 
            puts_verbose "Last"
            if is_vowel(@word[index - 1]) then 
                @buffer += letter
            else
                @syllables[-1] = @syllables[-1] + letter
                @buffer = ""
            end
            return index + 1
        end
    end

    # one of the major differences between OP and UP version
    # is how they treat consonant clusters in the middle of a word 
    # using this function clusters will be prioritized first
    # this is technically treating the current index
    # as the "start" of the word if it were in OP like case
    def cluster_first(index)
        puts_verbose "\tChecking if cluster at right of #{@word[index]}"
        next_index = index
        if is_consonant(index) then
            # check if a cluster 
            cluster = tree_match(@clusters, next_index)
            # if a cluster then add the current cluster to the current @buffer
            if cluster then 
                puts_verbose "\tCluster!"
                puts_verbose "\tCreating new syllable."
                integrate_buffer
                @buffer = cluster
                next_index = cluster.length + next_index
            end
        else 
            puts_verbose "\tNot a cluster"
        end
        return next_index
    end


    # integrates the current buffer to the syllables array
    def integrate_buffer(last=false)
        buffer = @buffer.sub("@", "ng")
        puts_verbose "\tOLD BUFFER: #{@buffer}"

        if @buffer.strip != "" then
            @syllables.push(buffer)
        end
        puts_verbose "\tNEW BUFFER: #{buffer}"
    end

    # ---------------------------------------------------# 
    # HELPER FUNCTIONS

    def is_vowel(index) 
        @vowels[@word[index]] == true
    end

    def is_consonant(index)
       # if it's not a vowel and not nil
       # and the valid input is just lowercase
       # a-z, it can just be  dichotomy between 
       # a vowel and a consonant
       (!is_vowel(index) && @word[index] != nil)
    end
    
    # -------------------------------------------------- #
    
    # driver function
    def syllabicate(word) 
  
        if @cache[word] then 
            return @cache[word]
        end

        # start with the first letter 
        @word = word

        # replace all `ng` to a single character placeholder @ 
        @word = @word.gsub("ng", "@")

        start

        syllables = @syllables

        # reset all 
        @syllables = []
        @buffer = ""

        @cache[word] = syllables
        
        syllables
    end
    
    # validty test function - from a tsv file
    def validity_test(test_file, report_file)
        ifile = File.open(test_file, "r:UTF-8", &:read)
        ofile = File.open(report_file, "w:UTF-8")

        words = {} 

        ifile.split("\n")[1..-1].each do |line| 
            tokens = line.split("\t")
            words[tokens[0].strip] = tokens[1].strip
        end
        
        ofile.syswrite "VALIDITY TEST FOR ORTOGRAPIYANG PAMBANSA VERSION\n" 
        ofile.syswrite "================================================\n"

        # DISPLAY TEST WORDS
        ofile.syswrite "TEST WORDS (#{words.length} word/s)\n"
        i = 0
        words.each do |word, correct| 
            ofile.syswrite "##{i+1} Word: " + 
                        word.ljust(words.keys.collect{|v| v.length}.max) + " | "
            ofile.syswrite "Expected: " + 
                        correct.ljust(words.values.collect{|v| v.length}.max) 
            ofile.syswrite "\n"
            i += 1
        end

        # MAKE TESTS 
        results = {} 
        score = 0 
        total = words.length
        ofile.syswrite "\n"
        words.each do |word, correct| 
            result = syllabicate(word).join("|")
            puts_verbose "#{result} : #{correct}"
            if result == correct then 
                score += 1
            end
            results[word] = result
        end

        # GET RESULTS 
        accuracy = score * 1.0 /total 
        ofile.syswrite "\n"

        # DISPLAY RESULTS 
        ofile.syswrite "RESULTS (#{accuracy * 100} %, #{score} right, #{total-score} wrong)\n"
        i = 0
        words.each do |word, correct| 
            result = results[word]
            ofile.syswrite "##{i+1} Word: " + 
                        word.ljust(words.keys.collect{|v| v.length}.max) + " | "
            ofile.syswrite "Expected: " + 
                        correct.ljust(words.values.collect{|v| v.length}.max) + " | "
            ofile.syswrite "Prediction: " + 
                        result.ljust(results.values.collect{|v| v.length}.max)  + " | "
            if result == correct then 
                ofile.syswrite "CORRECT"
            else
                ofile.syswrite "WRONG" 
            end
            ofile.syswrite "\n"
            
            i += 1
        end
    end
    
    # speed test function - please enter a lot like more than 
    # 1000 words for more generalized results
    def speedtest
        ifile = File.open("wordlist.txt", "r:UTF-8", &:read)
        words = ifile.split("\n")

        puts  "No display output, plain storage"
        start_time = Time.now.to_i
        store = {}
        words.each do |word| 
           store[word] = syllabicate(word)
        end
        end_time = Time.now.to_i
        puts "Start time: " + start_time.to_s
        puts "End time: " + end_time.to_s
        puts "Total time: " + (end_time - start_time).to_s + " seconds"
        puts "Total No. of Words: " + (words.length).to_s + " seconds"

        puts JSON.pretty_generate store
    end
end

