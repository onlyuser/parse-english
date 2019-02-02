[![Build Status](https://secure.travis-ci.org/onlyuser/parse-english.png)](http://travis-ci.org/onlyuser/parse-english)

parse-english
===========

Copyright (C) 2011-2017 <mailto:onlyuser@gmail.com>

About
-----

parse-english is a minimum viable English parser implemented in LexYacc.

See original prototype here: [NatLang](https://github.com/onlyuser/NatLang)

A Motivating Example
--------------------

input:
<pre>
the quick brown fox jumps over the lazy dog.
</pre>

output:
![picture alt](https://sites.google.com/site/onlyuser/files/ast_fox2.png "ast_fox2")

Usage
-----

<pre>
./demo/0_parse-english_full_nlp/bin/parse-english -e "the quick brown fox jumps over the lazy dog." -d | dot -Tpng -oast_fox2.png
</pre>

Requirements
------------

Unix tools and 3rd party components (accessible from $PATH):

    gcc flex bison

Supported Language Features
---------------------------

* Present tense
* Progressive tense
* Future tense
* Past tense
* Past perfect tense
* Passive voice
* Questions
* Conditionals
* Imperitive mood

Limitations
-----------

* Hard coded grammar & vocabulary.
* A brute force algorithm tries all supported interpretations of a sentence. This is slow for long sentences.
* BNF rules are suitable for specifying constituent-based phrase structure grammars, but are a poor fit for expressing non-local dependencies.

Make Targets
------------

<table>
    <tr><th> target </th><th> action                                                </th></tr>
    <tr><td> all    </td><td> make binaries                                         </td></tr>
    <tr><td> test   </td><td> all + run tests                                       </td></tr>
    <tr><td> pure   </td><td> test + use valgrind to check for memory leaks         </td></tr>
    <tr><td> dot    </td><td> test + generate .png graph for tests                  </td></tr>
    <tr><td> lint   </td><td> use cppcheck to perform static analysis on .cpp files </td></tr>
    <tr><td> doc    </td><td> use doxygen to generate documentation                 </td></tr>
    <tr><td> xml    </td><td> test + generate .xml for tests                        </td></tr>
    <tr><td> import </td><td> test + use ticpp to serialize-to/deserialize-from xml </td></tr>
    <tr><td> clean  </td><td> remove all intermediate files                         </td></tr>
</table>

References
---------

<dl>
    <dt>"Part-of-speech tagging"</dt>
    <dd>http://en.wikipedia.org/wiki/Part-of-speech_tagging</dd>
    <dt>"Princeton WordNet"</dt>
    <dd>http://wordnet.princeton.edu/</dd>
    <dt>"Syntactic Theory: A Unified Approach"</dt>
    <dd>ISBN: 0340706104</dd>
    <dt>"Enju - A fast, accurate, and deep parser for English"</dt>
    <dd>http://www.nactem.ac.uk/enju/</dd>
</dl>

Keywords
--------

    Natural Language Processing, English parser, Yacc, BNF
