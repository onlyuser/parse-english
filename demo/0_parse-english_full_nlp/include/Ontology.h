#ifndef ONTOLOGY_H_
#define ONTOLOGY_H_

#include "visitor/XLangVisitor.h" // visitor::Visitor
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "parse-englishLexerIDWrapper.h" // ID_XXX (yacc generated)
#include <algorithm>
#include <vector>
#include <map>
#include <string>

class NodeWrapper;
typedef std::vector<const xl::node::NodeIdentIFace*>            node_vector_t;
typedef std::map<const xl::node::NodeIdentIFace*, NodeWrapper*> node_wrapper_map_t;

bool is_sentence(const xl::node::NodeIdentIFace* _node);
bool is_clause(const xl::node::NodeIdentIFace* _node);
bool is_noun(const xl::node::NodeIdentIFace* _node);
bool is_verb(const xl::node::NodeIdentIFace* _node);
bool is_aux_verb(const xl::node::NodeIdentIFace* _node);
bool is_modal_verb(const xl::node::NodeIdentIFace* _node);
bool is_been(const xl::node::NodeIdentIFace* _node);
bool is_aux_not_v(const xl::node::NodeIdentIFace* _node);
bool is_be_target(const xl::node::NodeIdentIFace* _node);
bool is_verb_phrase(const xl::node::NodeIdentIFace* _node);
bool is_prep(const xl::node::NodeIdentIFace* _node);
bool is_prep_phrase(const xl::node::NodeIdentIFace* _node);

class NodeGatherer : public xl::visitor::VisitorDFS
{
public:
    NodeGatherer()
    {}
    void visit(const xl::node::SymbolNodeIFace*                                _node);
    void visit(const xl::node::TermNodeIFace<xl::node::NodeIdentIFace::IDENT>* _node);
    void visit_null();
    bool is_printer() const
    {
        return false;
    }
    const node_vector_t& get_not_nodes() const
    {
        return m_not_nodes;
    }
    const node_vector_t& get_sentence_nodes() const
    {
        return m_sentence_nodes;
    }
    const node_vector_t& get_clause_nodes() const
    {
        return m_clause_nodes;
    }
    const node_vector_t& get_verb_phrase_nodes() const
    {
        return m_verb_phrase_nodes;
    }
    const node_vector_t& get_prep_phrase_nodes() const
    {
        return m_prep_phrase_nodes;
    }
    const node_vector_t& get_noun_nodes() const
    {
        return m_noun_nodes;
    }
    const node_vector_t& get_verb_nodes() const
    {
        return m_verb_nodes;
    }
    const node_vector_t& get_prep_nodes() const
    {
        return m_prep_nodes;
    }

private:
    node_vector_t m_not_nodes;
    node_vector_t m_sentence_nodes;
    node_vector_t m_clause_nodes;
    node_vector_t m_verb_phrase_nodes;
    node_vector_t m_prep_phrase_nodes;
    node_vector_t m_noun_nodes;
    node_vector_t m_verb_nodes;
    node_vector_t m_prep_nodes;
};

class NodeWrapper
{
public:
    const xl::node::NodeIdentIFace* get_node() {
        return m_node;
    }
    virtual std::string to_string(int indent) const = 0;
    void set_parent(NodeWrapper* parent)
    {
        m_parent = parent;
    }
    NodeWrapper* get_parent() const
    {
        return m_parent;
    }
    void set_tag(std::string tag)
    {
        m_tag = tag;
    }

protected:
    NodeWrapper(const xl::node::NodeIdentIFace* node)
        : m_node(node),
          m_parent(NULL)
    {
    }
    virtual ~NodeWrapper()
    {
    }

protected:
    const xl::node::NodeIdentIFace* m_node;
          NodeWrapper*              m_parent;
          std::string               m_tag;
};

class Verb : public NodeWrapper
{
public:
    Verb(const xl::node::NodeIdentIFace* verb_node)
        : NodeWrapper(verb_node)
    {
    }
    std::string to_string(int indent) const;
};

class Noun : public NodeWrapper
{
public:
    Noun(const xl::node::NodeIdentIFace* noun_node)
        : NodeWrapper(noun_node)
    {
    }
    std::string to_string(int indent) const;

private:
    const xl::node::NodeIdentIFace* m_noun_node;
};

class Prep : public NodeWrapper
{
public:
    Prep(const xl::node::NodeIdentIFace* prep_node)
        : NodeWrapper(prep_node)
    {
    }
    std::string to_string(int indent) const;
};

class PrepPhrase : public NodeWrapper
{
public:
    PrepPhrase(const xl::node::NodeIdentIFace* prep_phrase_node)
        : NodeWrapper(prep_phrase_node),
          m_prep(NULL)
    {}
    virtual ~PrepPhrase()
    {
        for(std::vector<Noun*>::iterator p = m_indirect_objects.begin(); p != m_indirect_objects.end(); p++) {
            delete *p;
        }
    }
    void set_prep(Prep* prep)
    {
        m_prep = prep;
        prep->set_parent(this);
    }
    Prep* get_prep()
    {
        return m_prep;
    }
    void add_indirect_object(Noun* noun)
    {
        m_indirect_objects.push_back(noun);
        noun->set_parent(this);
    }
    std::vector<Noun*> &get_indirect_objects()
    {
        return m_indirect_objects;
    }
    std::string to_string(int indent = 0) const;

private:
    Prep*              m_prep;
    std::vector<Noun*> m_indirect_objects;
};

class VerbPhrase : public NodeWrapper
{
public:
    VerbPhrase(const xl::node::NodeIdentIFace* verb_phrase_node)
        : NodeWrapper(verb_phrase_node),
          m_verb(NULL),
          m_aux_verb(NULL),
          m_modal_verb(NULL),
          m_been(NULL),
          m_negated(false),
          m_passive_voice(false)
    {}
    virtual ~VerbPhrase()
    {
        if(m_verb) {
            delete m_verb;
        }
        for(std::vector<Noun*>::iterator p = m_direct_objects.begin(); p != m_direct_objects.end(); p++) {
            delete *p;
        }
        for(std::vector<PrepPhrase*>::iterator p = m_prep_phrases.begin(); p != m_prep_phrases.end(); p++) {
            delete *p;
        }
    }
    void set_verb(Verb* verb)
    {
        m_verb = verb;
        verb->set_parent(this);
    }
    void set_aux_verb(Verb* verb)
    {
        m_aux_verb = verb;
        verb->set_parent(this);
    }
    void set_modal_verb(Verb* verb)
    {
        m_modal_verb = verb;
        verb->set_parent(this);
    }
    void set_been(Verb* verb)
    {
        m_been = verb;
        verb->set_parent(this);
    }
    Verb* get_verb() const
    {
        return m_verb;
    }
    void add_direct_object(Noun* noun)
    {
        m_direct_objects.push_back(noun);
        noun->set_parent(this);
    }
    std::vector<Noun*> &get_direct_objects()
    {
        return m_direct_objects;
    }
    void add_prep_phrase(PrepPhrase* prep_phrase)
    {
        m_prep_phrases.push_back(prep_phrase);
        prep_phrase->set_parent(this);
    }
    std::vector<PrepPhrase*> &get_prep_phrases()
    {
        return m_prep_phrases;
    }
    void set_negated(bool negated)
    {
        m_negated = negated;
    }
    void set_passive_voice(bool passive_voice)
    {
        m_passive_voice = passive_voice;
    }
    bool is_passive_voice() const
    {
        return m_passive_voice;
    }
    std::string to_string(int indent = 0) const;
    bool empty() const
    {
        return !m_verb && !m_aux_verb && !m_modal_verb && !m_been && m_direct_objects.empty() && m_prep_phrases.empty();
    }

private:
    Verb*                     m_verb;
    Verb*                     m_aux_verb;
    Verb*                     m_modal_verb;
    Verb*                     m_been;
    std::vector<Noun*>        m_direct_objects;
    std::vector<PrepPhrase*>  m_prep_phrases;
    bool                      m_negated;
    bool                      m_passive_voice;
};

class Clause : public NodeWrapper
{
public:
    Clause(const xl::node::NodeIdentIFace* clause_node)
        : NodeWrapper(clause_node)
    {}
    virtual ~Clause()
    {
        for(std::vector<Noun*>::iterator p = m_subjects.begin(); p != m_subjects.end(); p++) {
            delete *p;
        }
    }
    void add_subject(Noun* noun)
    {
        m_subjects.push_back(noun);
        noun->set_parent(this);
    }
    std::vector<Noun*> &get_subjects()
    {
        return m_subjects;
    }
    void add_verb_phrase(VerbPhrase* verb_phrase)
    {
        m_verb_phrases.push_back(verb_phrase);
        verb_phrase->set_parent(this);
    }
    void remove_verb_phrase(VerbPhrase* verb_phrase)
    {
        std::vector<VerbPhrase*>::iterator p = std::find(m_verb_phrases.begin(), m_verb_phrases.end(), verb_phrase);
        if(p != m_verb_phrases.end()) {
            m_verb_phrases.erase(p);
        }
    }
    std::string to_string(int indent = 0) const;

private:
    std::vector<Noun*>       m_subjects;
    std::vector<VerbPhrase*> m_verb_phrases;
};

class Sentence : public NodeWrapper
{
public:
    Sentence(const xl::node::NodeIdentIFace* sentence_node)
        : NodeWrapper(sentence_node)
    {}
    virtual ~Sentence()
    {
        for(std::vector<Clause*>::iterator p = m_clauses.begin(); p != m_clauses.end(); p++) {
            delete *p;
        }
    }
    void add_clause(Clause* clause)
    {
        m_clauses.push_back(clause);
        clause->set_parent(this);
    }
    std::string to_string(int indent = 0) const;

private:
    std::vector<Clause*> m_clauses;
};

bool is_descendant_of(const xl::node::NodeIdentIFace* child, const xl::node::NodeIdentIFace* parent);
const xl::node::NodeIdentIFace* find_ancestor(const xl::node::NodeIdentIFace* child, bool (*filter)(const xl::node::NodeIdentIFace*), bool first_hit = false);
const xl::node::NodeIdentIFace* find_first_common_ancestor(const xl::node::NodeIdentIFace* node1, const xl::node::NodeIdentIFace* node2);
bool is_before(const xl::node::NodeIdentIFace* node1, const xl::node::NodeIdentIFace* node2);
bool find_ancestor_self_wrappers(const node_wrapper_map_t &node_wrapper_map,
                                 const xl::node::NodeIdentIFace* node, NodeWrapper** ancestor, NodeWrapper** self,
                                 bool (*filter)(const xl::node::NodeIdentIFace*), bool first_hit = false);
std::vector<Sentence*> extract_ontology(const xl::node::NodeIdentIFace* ast);

#endif
