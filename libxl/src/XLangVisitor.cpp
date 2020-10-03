// XLang
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

#include "visitor/XLangVisitor.h" // visitor::Visitor
#include "XLangString.h" // xl::escape

//#define DEBUG

namespace xl { namespace visitor {

void Visitor::visit(const node::TermNodeIFace<node::NodeIdentIFace::INT>* _node)
{
    m_output_ss << _node->value();
}
void Visitor::visit(const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>* _node)
{
    m_output_ss << _node->value();
}
void Visitor::visit(const node::TermNodeIFace<node::NodeIdentIFace::STRING>* _node)
{
    m_output_ss << '\"' << xl::escape(*_node->value()) << '\"';
}
void Visitor::visit(const node::TermNodeIFace<node::NodeIdentIFace::CHAR>* _node)
{
    m_output_ss << '\'' << xl::escape(_node->value()) << '\'';
}
void Visitor::visit(const node::TermNodeIFace<node::NodeIdentIFace::IDENT>* _node)
{
    m_output_ss << *_node->value();
}
void Visitor::visit_null()
{
    m_output_ss << "NULL";
}
void Visitor::dispatch_visit(const node::NodeIdentIFace* unknown)
{
    if(!unknown) {
        if(m_allow_visit_null) {
            visit_null();
        }
        return;
    }
    #ifdef DEBUG
        if(is_printer()) {
            m_output_ss << "{depth=" << unknown->depth()
                        << ", height=" << unknown->height()
                        << ", bfs_index=" << unknown->bfs_index() << "}" << std::endl;
        }
    #endif
    switch(unknown->type()) {
        case node::NodeIdentIFace::INT:
            visit(dynamic_cast<const node::TermNodeIFace<node::NodeIdentIFace::INT>*>(unknown));
            break;
        case node::NodeIdentIFace::FLOAT:
            visit(dynamic_cast<const node::TermNodeIFace<node::NodeIdentIFace::FLOAT>*>(unknown));
            break;
        case node::NodeIdentIFace::STRING:
            visit(dynamic_cast<const node::TermNodeIFace<node::NodeIdentIFace::STRING>*>(unknown));
            break;
        case node::NodeIdentIFace::CHAR:
            visit(dynamic_cast<const node::TermNodeIFace<node::NodeIdentIFace::CHAR>*>(unknown));
            break;
        case node::NodeIdentIFace::IDENT:
            visit(dynamic_cast<const node::TermNodeIFace<node::NodeIdentIFace::IDENT>*>(unknown));
            break;
        case node::NodeIdentIFace::SYMBOL:
            visit(dynamic_cast<const node::SymbolNodeIFace*>(unknown));
            break;
        default:
            m_output_ss << "unknown node type" << std::endl;
            break;
    }
}

void VisitorDFS::visit(const node::SymbolNodeIFace* _node)
{
    if(m_filter_cb) {
        if(_node->is_root() && !m_filter_cb(_node)) {
            return;
        }
    }
    const node::NodeIdentIFace* child = NULL;
    if(!iter_next_child(_node, &child)) {
        return;
    }
    do {
        if(m_filter_cb) {
            if(child->type() == node::NodeIdentIFace::SYMBOL && !m_filter_cb(child)) {
                VisitorDFS::visit(dynamic_cast<const node::SymbolNodeIFace*>(child));
                continue;
            }
        }
        dispatch_visit(child);
    } while(iter_next_child(NULL, &child));
}

void VisitorDFS::push_state(const node::SymbolNodeIFace* _node)
{
    m_visit_state_stack.push(visit_state_t(_node, 0));
}

bool VisitorDFS::iter_next_state()
{
    if(end_of_visitation()) {
        pop_state();
        return false;
    }
    m_visit_state_stack.top().second++;
    return true;
}

bool VisitorDFS::get_current_node(const node::NodeIdentIFace** _node) const
{
    if(end_of_visitation()) {
        return false;
    }
    const visit_state_t &visit_state = m_visit_state_stack.top();
    if(_node) {
        *_node = (*visit_state.first)[visit_state.second];
    }
    return true;
}

bool VisitorDFS::end_of_visitation() const
{
    if(m_visit_state_stack.empty()) {
        return true;
    }
    return m_visit_state_stack.top().second == static_cast<int>(m_visit_state_stack.top().first->size());
}

void VisitorBFS::push_state(const node::SymbolNodeIFace* _node)
{
    m_visit_state_stack.push(visit_state_t());
    m_visit_state_stack.top().push(_node);
}

bool VisitorBFS::iter_next_state()
{
    if(end_of_visitation()) {
        pop_state();
        return false;
    }
    visit_state_t &visit_state = m_visit_state_stack.top();
    const node::NodeIdentIFace* _node = NULL;
    do {
        _node = visit_state.front();
        if(_node && _node->type() == node::NodeIdentIFace::SYMBOL) {
            auto symbol = dynamic_cast<const node::SymbolNodeIFace*>(_node);
            for(int i = 0; i<static_cast<int>(symbol->size()); i++) {
                visit_state.push((*symbol)[i]);
            }
        }
        visit_state.pop();
    } while(m_filter_cb && m_filter_cb(_node) && visit_state.size());
    return true;
}

bool VisitorBFS::get_current_node(const node::NodeIdentIFace** _node) const
{
    if(end_of_visitation()) {
        return false;
    }
    const visit_state_t &visit_state = m_visit_state_stack.top();
    if(_node) {
        *_node = visit_state.front();
    }
    return true;
}

bool VisitorBFS::end_of_visitation() const
{
    if(m_visit_state_stack.empty()) {
        return true;
    }
    return m_visit_state_stack.top().empty();
}

} }
