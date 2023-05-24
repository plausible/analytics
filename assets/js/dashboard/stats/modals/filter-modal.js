import React from "react"
import { withRouter } from 'react-router-dom'
import Modal from './modal'
import RegularFilterModal from './regular-filter-modal'
import PropFilterModal from "./prop-filter-modal"

function FilterModal(props) {
  function renderBody() {
    const filterGroup = props.match.params.field || 'page'
    if (filterGroup === 'props') {
      return <PropFilterModal site={props.site} />
    } else {
      return <RegularFilterModal site={props.site} filterGroup={filterGroup} />
    }
  }

  return (
    <Modal site={props.site} maxWidth="460px">
      {renderBody()}
    </Modal>
  )
}

export default withRouter(FilterModal)
