#include <Ontology.h>
#include <algorithm>
#include <map>
#include <set>
#include <string>
#include <iostream>

bool is_not(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_NOT);
}

bool is_sentence(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_S);
}

bool is_clause(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_CLAUSE);
}

bool is_noun(const xl::node::NodeIdentIFace* _node)
{
    switch(_node->lexer_id()) {
        case ID_N:
        case ID_DEM:
            return true;
        default:
            return false;
    }
    return false;
}

bool is_verb(const xl::node::NodeIdentIFace* _node)
{
    switch(_node->lexer_id()) {
        case ID_V:
        case ID_VPAST:
        case ID_VGERUND:

        case ID_VPASTPERF:
        case ID_BE:
        case ID_BEING:
        case ID_BEEN:

        case ID_DO:
        case ID_HAVE:
        case ID_MODAL:
            return true;
        default:
            return false;
    }
    return false;
}

bool is_aux_verb(const xl::node::NodeIdentIFace* _node)
{
    switch(_node->lexer_id()) {
        case ID_AUX_V:

        case ID_BE_NOT_OR_FREQ:
        case ID_DO_NOT_OR_FREQ:
        case ID_HAVE_NOT_OR_FREQ:
            return true;
        default:
            return false;
    }
    return false;
}

bool is_modal_verb(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_MODAL_NOT_OR_FREQ);
}

bool is_been(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_BEEN);
}

bool is_aux_not_v(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_AUX_NOT_V);
}

bool is_be_target(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_BE_TARGET);
}

bool is_verb_phrase(const xl::node::NodeIdentIFace* _node)
{
    switch(_node->lexer_id()) {
        case ID_VP:

        case ID_V_NP:
        case ID_VPAST_NP:
        case ID_VGERUND_NP:

        case ID_AUX_V:
        case ID_AUX_NOT_V:

        case ID_HAVE_TARGET:

        case ID_BE_NOT_OR_FREQ:
        case ID_DO_NOT_OR_FREQ:
        case ID_HAVE_NOT_OR_FREQ:
        case ID_MODAL_NOT_OR_FREQ:
            return true;
        default:
            return false;
    }
    return false;
}

bool is_prep(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_PREP);
}

bool is_prep_phrase(const xl::node::NodeIdentIFace* _node)
{
    return (_node->lexer_id() == ID_PREP_NP);
}

void NodeGatherer::visit(const xl::node::SymbolNodeIFace* _node)
{
    if(is_sentence(dynamic_cast<const xl::node::NodeIdentIFace*>(_node))) {
        m_sentence_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_clause(dynamic_cast<const xl::node::NodeIdentIFace*>(_node))) {
        m_clause_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_verb_phrase(dynamic_cast<const xl::node::NodeIdentIFace*>(_node))) {
        m_verb_phrase_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_prep_phrase(dynamic_cast<const xl::node::NodeIdentIFace*>(_node))) {
        m_prep_phrase_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    xl::visitor::VisitorDFS::visit(_node);
}

void NodeGatherer::visit(const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>* _node)
{
    if(is_not(_node)) {
        m_not_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_noun(_node)) {
        m_noun_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_verb(_node)) {
        m_verb_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
    if(is_prep(_node)) {
        m_prep_nodes.push_back(dynamic_cast<const xl::node::NodeIdentIFace*>(_node));
    }
}

void NodeGatherer::visit_null() {
}

std::string Noun::to_string(int indent) const
{
    std::stringstream ss;
    std::string name = m_node ? *dynamic_cast<const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>*>(m_node)->value() : m_tag;
    ss << std::string(4 * indent, ' ') << "(NOUN \"" << name << "\")" << std::endl;
    return ss.str();
}

std::string Verb::to_string(int indent) const
{
    std::stringstream ss;
    std::string name = m_node ? *dynamic_cast<const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>*>(m_node)->value() : m_tag;
    ss << std::string(4 * indent, ' ') << "(VERB \"" << name << "\")" << std::endl;
    return ss.str();
}

std::string Prep::to_string(int indent) const
{
    std::stringstream ss;
    std::string name = m_node ? *dynamic_cast<const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>*>(m_node)->value() : m_tag;
    ss << std::string(4 * indent, ' ') << "(PREP \"" << name << "\")" << std::endl;
    return ss.str();
}

std::string PrepPhrase::to_string(int indent) const
{
    std::stringstream ss;
    std::string indent_str           = std::string(4 * indent, ' ');
    std::string next_indent_str      = std::string(4 * (indent + 1), ' ');
    std::string next_next_indent_str = std::string(4 * (indent + 2), ' ');
    ss << indent_str << "(PREP_PHRASE" << std::endl;

    if(m_prep) {
        ss << m_prep->to_string(indent + 1);
    }

    if(m_indirect_objects.size()) {
        ss << next_indent_str << "(INDIRECT_OBJECTS" << std::endl;
        for(std::vector<Noun*>::const_iterator p = m_indirect_objects.begin(); p != m_indirect_objects.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    ss << indent_str << ")" << std::endl;
    return ss.str();
}

std::string VerbPhrase::to_string(int indent) const
{
    std::stringstream ss;
    std::string indent_str           = std::string(4 * indent, ' ');
    std::string next_indent_str      = std::string(4 * (indent + 1), ' ');
    std::string next_next_indent_str = std::string(4 * (indent + 2), ' ');
    ss << indent_str << "(VERB_PHRASE" << std::endl;

    if(m_modal_verb) {
        ss << next_indent_str << "(MODAL_VERB" << std::endl;
        ss << m_modal_verb->to_string(indent + 2);
        ss << next_indent_str << ")" << std::endl;

        if(m_negated) {
            ss << next_indent_str << "(NOT)" << std::endl;
        }
    }

    if(m_aux_verb) {
        ss << next_indent_str << "(AUX_VERB" << std::endl;
        ss << m_aux_verb->to_string(indent + 2);
        ss << next_indent_str << ")" << std::endl;

        if(!m_modal_verb && m_negated) {
            ss << next_indent_str << "(NOT)" << std::endl;
        }
    }

    if(m_been) {
        ss << next_indent_str << "(BEEN" << std::endl;
        ss << m_been->to_string(indent + 2);
        ss << next_indent_str << ")" << std::endl;
    }

    if(m_passive_voice) {
        ss << next_indent_str << "(PASSIVE_VOICE)" << std::endl;
    }

    if(m_verb) {
        ss << m_verb->to_string(indent + 1);
    }

    if(m_direct_objects.size()) {
        ss << next_indent_str << "(DIRECT_OBJECTS" << std::endl;
        for(std::vector<Noun*>::const_iterator p = m_direct_objects.begin(); p != m_direct_objects.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    if(m_prep_phrases.size()) {
        ss << next_indent_str << "(PREP_PHRASES" << std::endl;
        for(std::vector<PrepPhrase*>::const_iterator p = m_prep_phrases.begin(); p != m_prep_phrases.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    ss << indent_str << ")" << std::endl;
    return ss.str();
}

std::string Clause::to_string(int indent) const
{
    std::stringstream ss;
    std::string indent_str           = std::string(4 * indent, ' ');
    std::string next_indent_str      = std::string(4 * (indent + 1), ' ');
    std::string next_next_indent_str = std::string(4 * (indent + 2), ' ');
    ss << indent_str << "(CLAUSE" << std::endl;

    if(m_subjects.size()) {
        ss << next_indent_str << "(SUBJECTS" << std::endl;
        for(std::vector<Noun*>::const_iterator p = m_subjects.begin(); p != m_subjects.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    if(m_verb_phrases.size()) {
        ss << next_indent_str << "(VERB_PHRASES" << std::endl;
        for(std::vector<VerbPhrase*>::const_iterator p = m_verb_phrases.begin(); p != m_verb_phrases.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    ss << indent_str << ")" << std::endl;
    return ss.str();
}

std::string Sentence::to_string(int indent) const
{
    std::stringstream ss;
    std::string indent_str           = std::string(4 * indent, ' ');
    std::string next_indent_str      = std::string(4 * (indent + 1), ' ');
    std::string next_next_indent_str = std::string(4 * (indent + 2), ' ');
    ss << indent_str << "(SENTENCE" << std::endl;

    if(m_clauses.size()) {
        ss << next_indent_str << "(CLAUSES" << std::endl;
        for(std::vector<Clause*>::const_iterator p = m_clauses.begin(); p != m_clauses.end(); p++) {
            ss << (*p)->to_string(indent + 2);
        }
        ss << next_indent_str << ")" << std::endl;
    }

    ss << indent_str << ")" << std::endl;
    return ss.str();
}

bool is_descendant_of(const xl::node::NodeIdentIFace* child, const xl::node::NodeIdentIFace* parent)
{
    if(child == parent) {
        return false;
    }
    const xl::node::NodeIdentIFace* node = child;
    while(node) {
        node = node->parent();
        if(node == parent) {
            return true;
        }
    }
    return false;
}

const xl::node::NodeIdentIFace* find_ancestor(const xl::node::NodeIdentIFace* child, bool (*filter)(const xl::node::NodeIdentIFace*), bool first_hit)
{
    const xl::node::NodeIdentIFace* result = NULL;
    const xl::node::NodeIdentIFace* node = child;
    while(node) {
        node = node->parent();
        if(node && filter(node)) {
            if(first_hit) {
                return node;
            }
            result = node;
        }
    }
    return result;
}

const xl::node::NodeIdentIFace* find_first_common_ancestor(const xl::node::NodeIdentIFace* node1, const xl::node::NodeIdentIFace* node2)
{
    std::set<const xl::node::NodeIdentIFace*> node1_lineage;

    {
        const xl::node::NodeIdentIFace* node = node1;
        while(node) {
            node1_lineage.insert(node);
            node = node->parent();
        }
    }

    {
        const xl::node::NodeIdentIFace* node = node2;
        while(node) {
            if(node1_lineage.find(node) != node1_lineage.end()) {
                return node;
            }
            node = node->parent();
        }
    }

    return NULL;
}

bool is_before(const xl::node::NodeIdentIFace* node1, const xl::node::NodeIdentIFace* node2)
{
    const xl::node::NodeIdentIFace* first_common_ancestor = find_first_common_ancestor(node1, node2);

    const xl::node::NodeIdentIFace* node1_second_to_last = NULL;

    {
        const xl::node::NodeIdentIFace* node = node1;
        while(node) {
            if(node == first_common_ancestor) {
                break;
            }
            node1_second_to_last = node;
            node = node->parent();
        }
    }

    const xl::node::NodeIdentIFace* node2_second_to_last = NULL;

    {
        const xl::node::NodeIdentIFace* node = node2;
        while(node) {
            if(node == first_common_ancestor) {
                break;
            }
            node2_second_to_last = node;
            node = node->parent();
        }
    }

    return node1_second_to_last->index() < node2_second_to_last->index();
}

bool find_ancestor_self_wrappers(const node_wrapper_map_t &node_wrapper_map,
                                 const xl::node::NodeIdentIFace* node, NodeWrapper** ancestor, NodeWrapper** self,
                                 bool (*filter)(const xl::node::NodeIdentIFace*), bool first_hit)
{
    // find ancestor
    if(ancestor) {
        const xl::node::NodeIdentIFace* ancestor_node = find_ancestor(node, filter, first_hit);
        if(!ancestor_node) {
            return false;
        }
        node_wrapper_map_t::const_iterator p = node_wrapper_map.find(ancestor_node);
        if(p == node_wrapper_map.end()) {
            return false;
        }
        *ancestor = (*p).second;
    }

    // find self
    if(self) {
        node_wrapper_map_t::const_iterator q = node_wrapper_map.find(node);
        if(q == node_wrapper_map.end()) {
            return false;
        }
        *self = (*q).second;
    }

    return true;
}

std::vector<Sentence*> extract_ontology(const xl::node::NodeIdentIFace* ast)
{
    //==============
    // collect nodes
    //==============

    NodeGatherer v;
    v.dispatch_visit(ast);
    const node_vector_t &not_nodes         = v.get_not_nodes();
    const node_vector_t &sentence_nodes    = v.get_sentence_nodes();
    const node_vector_t &clauses_nodes     = v.get_clause_nodes();
    const node_vector_t &verb_phrase_nodes = v.get_verb_phrase_nodes();
    const node_vector_t &prep_phrase_nodes = v.get_prep_phrase_nodes();
    const node_vector_t &noun_nodes        = v.get_noun_nodes();
    const node_vector_t &verb_nodes        = v.get_verb_nodes();
    const node_vector_t &prep_nodes        = v.get_prep_nodes();

    //===============
    // build wrappers
    //===============

    node_wrapper_map_t node_wrapper_map;
    for(node_vector_t::const_iterator p = sentence_nodes.begin();    p != sentence_nodes.end();    p++) { node_wrapper_map.insert(std::make_pair(*p, new Sentence(*p))); }
    for(node_vector_t::const_iterator p = clauses_nodes.begin();     p != clauses_nodes.end();     p++) { node_wrapper_map.insert(std::make_pair(*p, new Clause(*p))); }
    for(node_vector_t::const_iterator p = verb_phrase_nodes.begin(); p != verb_phrase_nodes.end(); p++) { node_wrapper_map.insert(std::make_pair(*p, new VerbPhrase(*p))); }
    for(node_vector_t::const_iterator p = prep_phrase_nodes.begin(); p != prep_phrase_nodes.end(); p++) { node_wrapper_map.insert(std::make_pair(*p, new PrepPhrase(*p))); }
    for(node_vector_t::const_iterator p = verb_nodes.begin();        p != verb_nodes.end();        p++) { node_wrapper_map.insert(std::make_pair(*p, new Verb(*p))); }
    for(node_vector_t::const_iterator p = prep_nodes.begin();        p != prep_nodes.end();        p++) { node_wrapper_map.insert(std::make_pair(*p, new Prep(*p))); }
    for(node_vector_t::const_iterator p = noun_nodes.begin();        p != noun_nodes.end();        p++) { node_wrapper_map.insert(std::make_pair(*p, new Noun(*p))); }

    //========
    // clauses
    //========

    for(node_vector_t::const_iterator p = clauses_nodes.begin(); p != clauses_nodes.end(); p++) {
        Sentence* sentence_ancestor = NULL;
        Clause*   clause            = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&sentence_ancestor), reinterpret_cast<NodeWrapper**>(&clause), is_sentence)) {
            continue;
        }

        // add clause to sentence
        sentence_ancestor->add_clause(clause);
    }

    //=============
    // verb_phrases
    //=============

    for(node_vector_t::const_iterator p = verb_phrase_nodes.begin(); p != verb_phrase_nodes.end(); p++) {
        Clause*     clause_ancestor = NULL;
        VerbPhrase* verb_phrase     = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&clause_ancestor), reinterpret_cast<NodeWrapper**>(&verb_phrase), is_clause)) {
            continue;
        }

        // add verb phrase to clause
        clause_ancestor->add_verb_phrase(verb_phrase);
    }

    //=============
    // prep_phrases
    //=============

    for(node_vector_t::const_iterator p = prep_phrase_nodes.begin(); p != prep_phrase_nodes.end(); p++) {
        VerbPhrase* verb_phrase_ancestor = NULL;
        PrepPhrase* prep_phrase          = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&verb_phrase_ancestor), reinterpret_cast<NodeWrapper**>(&prep_phrase), is_verb_phrase)) {
            continue;
        }

        // add prep phrase to verb phrase
        verb_phrase_ancestor->add_prep_phrase(prep_phrase);
    }

    //======
    // verbs
    //======

    for(node_vector_t::const_iterator p = verb_nodes.begin(); p != verb_nodes.end(); p++) {
        VerbPhrase* verb_phrase_ancestor = NULL;
        Verb*       verb                 = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&verb_phrase_ancestor), reinterpret_cast<NodeWrapper**>(&verb), is_verb_phrase)) {
            continue;
        }

        // detect "passive_voice"
        if(find_ancestor(*p, is_aux_not_v) && find_ancestor(*p, is_be_target)) {
            verb_phrase_ancestor->set_passive_voice(true);
        }

        // detect "been"
        if(is_been(*p)) {
            verb_phrase_ancestor->set_been(verb);
            continue;
        }

        // set verb to verb phrase ancestor
        const xl::node::NodeIdentIFace* first_verb_phrase_ancestor_node = find_ancestor(*p, is_verb_phrase, true);
        if(!first_verb_phrase_ancestor_node) {
            continue;
        }
        if(is_aux_verb(first_verb_phrase_ancestor_node)) {
            verb_phrase_ancestor->set_aux_verb(verb);
        } else if(is_modal_verb(first_verb_phrase_ancestor_node)) {
            verb_phrase_ancestor->set_modal_verb(verb);
        } else {
            verb_phrase_ancestor->set_verb(verb);
        }
    }

    //======
    // nouns
    //======

    for(node_vector_t::const_iterator p = noun_nodes.begin(); p != noun_nodes.end(); p++) {
        Clause* clause_ancestor = NULL;
        Noun*   noun            = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&clause_ancestor), reinterpret_cast<NodeWrapper**>(&noun), is_clause)) {
            continue;
        }

        VerbPhrase* verb_phrase_ancestor = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&verb_phrase_ancestor), NULL, is_verb_phrase)) {
            // add subject to clause ancestor
            clause_ancestor->add_subject(noun);
            continue;
        }

        // NOTE: supports "i gave it to him"
        // NOTE: supports "i gave him it"
        PrepPhrase* first_prep_phrase_ancestor = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&first_prep_phrase_ancestor), NULL, is_prep_phrase, true)) {
            if(verb_phrase_ancestor->get_direct_objects().empty()) {
                // if no direct object, add direct object to verb phrase ancestor
                verb_phrase_ancestor->add_direct_object(noun);
            } else {
                // if already have direct objects, add noun to indirect objects, create new prep "to", and swap direct objects with indirect objects
                Prep* prep = new Prep(NULL);
                prep->set_tag("to");
                PrepPhrase* prep_phrase = new PrepPhrase(NULL);
                prep_phrase->set_prep(prep);
                prep_phrase->add_indirect_object(noun);
                verb_phrase_ancestor->add_prep_phrase(prep_phrase);

                // EXAMPLE
                // =======
                //
                //    i      gave   him         it
                // 1. <SUBJ> <VERB> <DIR_OBJ>   <INDIR_OBJ>
                //                      \             /
                //                       +---swap----+
                //
                // 2. <SUBJ> <VERB> <INDIR_OBJ> <DIR_OBJ>
                std::swap(verb_phrase_ancestor->get_direct_objects(), prep_phrase->get_indirect_objects());
            }
            continue;
        }

        // add indirect object to prep phrase ancestor
        first_prep_phrase_ancestor->add_indirect_object(noun);
    }

    //======
    // preps
    //======

    for(node_vector_t::const_iterator p = prep_nodes.begin(); p != prep_nodes.end(); p++) {
        PrepPhrase* first_prep_phrase_ancestor = NULL;
        Prep*       prep                       = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&first_prep_phrase_ancestor), reinterpret_cast<NodeWrapper**>(&prep), is_prep_phrase, true)) {
            continue;
        }

        // set prep to prep phrase ancestor
        first_prep_phrase_ancestor->set_prep(prep);
    }

    //=====
    // nots
    //=====

    for(node_vector_t::const_iterator p = not_nodes.begin(); p != not_nodes.end(); p++) {
        VerbPhrase* verb_phrase_ancestor = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&verb_phrase_ancestor), NULL, is_verb_phrase)) {
            continue;
        }

        // set negated to verb phrase ancestor
        verb_phrase_ancestor->set_negated(true);
    }

    // remove empty verb phrases
    for(node_vector_t::const_reverse_iterator p = verb_phrase_nodes.rbegin(); p != verb_phrase_nodes.rend(); p++) {
        VerbPhrase* verb_phrase = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, NULL, reinterpret_cast<NodeWrapper**>(&verb_phrase), NULL)) {
            continue;
        }

        // remove self from parent
        if(verb_phrase->empty()) {
            dynamic_cast<Clause*>(verb_phrase->get_parent())->remove_verb_phrase(verb_phrase);
        }
    }

    //=======================
    // passive voice handling
    //=======================

    std::set<VerbPhrase*> visited_verb_phrase_ancestors;
    for(node_vector_t::const_iterator p = verb_nodes.begin(); p != verb_nodes.end(); p++) {
        VerbPhrase* verb_phrase_ancestor = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&verb_phrase_ancestor), NULL, is_verb_phrase)) {
            continue;
        }

        // for unique verb phrase ancestors
        if(visited_verb_phrase_ancestors.find(verb_phrase_ancestor) != visited_verb_phrase_ancestors.end()) {
            continue;
        }

        // NOTE: supports "it was given to him"
        // NOTE: supports "it was given by me"
        // NOTE: supports "he was given it"
        // NOTE: fails with "to him, it was given"
        // NOTE: fails with "he was given it by me"
        if(verb_phrase_ancestor->is_passive_voice()) {
            Clause* clause_ancestor = NULL;
            if(!find_ancestor_self_wrappers(node_wrapper_map, *p, reinterpret_cast<NodeWrapper**>(&clause_ancestor), NULL, is_clause)) {
                continue;
            }

            std::vector<Noun*>       &subjects     = clause_ancestor->get_subjects();
            std::vector<PrepPhrase*> &prep_phrases = verb_phrase_ancestor->get_prep_phrases();

            if(prep_phrases.size()) {
                // if passive voice and have prep, swap subject with direct object

                // EXAMPLE
                // =======
                //
                //    it                  was-given to-him
                // 1. <SUBJ>    <DIR_OBJ> <VERB>    <INDIR_OBJ>
                //       \          /
                //        +--swap--+
                //
                // 2. <DIR_OBJ> <SUBJ>    <VERB>    <INDIR_OBJ>
                std::swap(subjects, verb_phrase_ancestor->get_direct_objects());

                // if passive voice and prep is "by", swap subject with indirect object
                for(std::vector<PrepPhrase*>::iterator p = prep_phrases.begin(); p != prep_phrases.end(); p++) {
                    Prep* prep = (*p)->get_prep();
                    std::string prep_str = *dynamic_cast<const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>*>(prep->get_node())->value();
                    if(prep_str == "{by}") {
                        // EXAMPLE
                        // =======
                        //
                        //    it                    was-given to-him      by-me
                        // 1. <DIR_OBJ> <SUBJ>      <VERB>    <INDIR_OBJ> <INDIR_OBJ>
                        //                 \                                    /
                        //                  +---------------swap---------------+
                        //
                        // 2. <DIR_OBJ> <INDIR_OBJ> <VERB>    <INDIR_OBJ> <SUBJ>
                        //                    |
                        //                  remove
                        //
                        // 3. <DIR_OBJ>             <VERB>    <INDIR_OBJ> <SUBJ>
                        std::swap(subjects, (*p)->get_indirect_objects());

                        // remove empty prep phrase after swap
                        prep_phrases.erase(p);
                        break;
                    }
                }
            } else {
                // if passive voice and no prep, create new prep "to" and swap subject with indirect object
                Prep* prep = new Prep(NULL);
                prep->set_tag("to");
                PrepPhrase* prep_phrase = new PrepPhrase(NULL);
                prep_phrase->set_prep(prep);
                verb_phrase_ancestor->add_prep_phrase(prep_phrase);

                // EXAMPLE
                // =======
                //
                //    he          was-given it
                // 1. <SUBJ>      <VERB>    <DIR_OBJ> <INDIR_OBJ>
                //       \                                  /
                //        +--------------swap--------------+
                //
                // 2. <INDIR_OBJ> <VERB>    <DIR_OBJ> <SUBJ>
                std::swap(subjects, prep_phrase->get_indirect_objects());
            }

            visited_verb_phrase_ancestors.insert(verb_phrase_ancestor);
        }
    }

    //==========
    // sentences
    //==========

    std::vector<Sentence*> sentences;
    for(node_vector_t::const_iterator p = sentence_nodes.begin(); p != sentence_nodes.end(); p++) {
        Sentence* sentence = NULL;
        if(!find_ancestor_self_wrappers(node_wrapper_map, *p, NULL, reinterpret_cast<NodeWrapper**>(&sentence), is_sentence)) {
            continue;
        }

        // add to result
        sentences.push_back(sentence);
    }

    return sentences;
}
