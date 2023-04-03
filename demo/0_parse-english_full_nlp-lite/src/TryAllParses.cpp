// parse-english
// -- A minimum viable English parser implemented in LexYacc
// Copyright (C) 2011 onlyuser <mailto:onlyuser@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

#include "../../0_parse-english_full_nlp-lite/include/TryAllParses.h"

#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "XLangAlloc.h" // Allocator
#include "XLangString.h" // xl::tokenize
#include "XLangSystem.h" // xl::system::shell_capture
#include <vector> // std::vector
#include <list> // std::list
#include <stack> // std::stack
#include <string> // std::string
#include <sstream> // std::stringstream
#include <algorithm> // std::sort
#include <iostream> // std::cerr

#include "parse-english.h"
#include "parse-englishLexerIDWrapper.h" // ID_XXX (yacc generated)

bool get_pos_options(std::string              word,
                    std::vector<std::string>* pos_options)
{
    if(word.empty() || !pos_options) {
        return false;
    }
    if(word == "and" || word == "nor" || word == "but" || word == "or" || word == "yet") {
        pos_options->push_back("CLAUSE(CONJ)");
        pos_options->push_back("NP(CONJ)");
        pos_options->push_back("VP(CONJ)");
    }
    return pos_options->size();
}

void build_all_paths_from_pos_options(std::list<std::vector<int> >*                 all_paths,   // OUT
                                      const std::vector<std::vector<std::string> >& pos_table,   // IN
                                      std::vector<int>*                             path_so_far, // TEMP
                                      int                                           word_index)  // TEMP
{
    if(!all_paths) {
        return;
    }

    std::vector<int>* _path_to_use = NULL;
    if(path_so_far) {
        _path_to_use = path_so_far;
    } else {
        _path_to_use = new std::vector<int>(pos_table.size());
        if(!_path_to_use) {
            return;
        }
    }

    // stop condition
    if(static_cast<size_t>(word_index) == pos_table.size()) { // reached last word
        all_paths->push_back(*_path_to_use);

        // cleanup
        if(!path_so_far) {
            delete _path_to_use;
        }
        return;
    }

    // dynamic programming step
    const std::vector<std::string> &pos_options = pos_table[word_index];
    for(int pos_index = 0; pos_index < static_cast<int>(pos_options.size()); pos_index++) {
        (*_path_to_use)[word_index] = pos_index;
        build_all_paths_from_pos_options(all_paths,
                                         pos_table,
                                         _path_to_use,
                                         word_index + 1);
    }

    // cleanup
    if(!path_so_far) {
        delete _path_to_use;
    }
}

void build_pos_paths_from_sentence(std::list<std::vector<std::string> >*  all_paths_str, // OUT
                                   std::string                            sentence,      // IN
                                   std::stringstream                     &shared_info_messages)
{
    if(!all_paths_str) {
        return;
    }

    {
        std::string msg = "Step 1/4. Tag POS:";
        std::string bar = std::string(msg.length(), '=');
        shared_info_messages << std::endl << bar << std::endl << msg << std::endl << bar << std::endl << std::endl;
    }

    // populate pos_table from words
    std::vector<std::vector<std::string> > pos_table;
    std::vector<std::string> words = xl::tokenize(sentence);
    pos_table.resize(words.size());
    int word_index = 0;
    for(std::vector<std::string>::iterator p = words.begin(); p != words.end(); p++) {
        std::vector<std::string> pos_options;
        if(get_pos_options(*p, &pos_options)) {
            for(std::vector<std::string>::iterator q = pos_options.begin(); q != pos_options.end(); q++) {
                pos_table[word_index].push_back(std::string("{") + *p + "}" + *q);
            }
        } else {
            pos_table[word_index].push_back(std::string("{") + *p + "}" + *p);
        }

        // print debug messages
        {
            shared_info_messages << "INFO: {" << *p << "}:\t";
            if(pos_options.size()) {
                for(std::vector<std::string>::iterator r = pos_options.begin(); r != pos_options.end(); r++) {
                    shared_info_messages << *r;
                    if(r != --pos_options.end()) {
                        shared_info_messages << " ";
                    }
                }
            } else {
                shared_info_messages << *p;
            }
            shared_info_messages << std::endl;
        }

        word_index++;
    }

    {
        std::string msg = "Step 2/4. Enumerate POS-paths:";
        std::string bar = std::string(msg.length(), '=');
        shared_info_messages << std::endl << bar << std::endl << msg << std::endl << bar << std::endl << std::endl;
    }

    // populate all_paths from pos_table
    std::list<std::vector<int> > all_paths;
    build_all_paths_from_pos_options(&all_paths, pos_table);

    // populate all_paths_str from all_paths and print results
    int path_index = 0;
    for(std::list<std::vector<int> >::const_iterator p = all_paths.begin(); p != all_paths.end(); p++) {
        std::vector<std::string> path_str;
        const std::vector<int> &path = *p;

        int word_index = 0;
        for(std::vector<int>::const_iterator q = path.begin(); q != path.end(); q++) {
            path_str.push_back(pos_table[word_index][*q]);
            word_index++;
        }

        // print debug messages
        {
            int word_index = 0;
            shared_info_messages << "INFO: Path #" << path_index << ": ";
            for(std::vector<int>::const_iterator r = path.begin(); r != path.end(); r++) {
                shared_info_messages << pos_table[word_index][*r];
                if(r != --path.end()) {
                    shared_info_messages << " ";
                }
                word_index++;
            }
            shared_info_messages << std::endl;
        }

        all_paths_str->push_back(path_str);
        path_index++;
    }
}
