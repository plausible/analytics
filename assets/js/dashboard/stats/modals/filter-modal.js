import React from "react"
import { withRouter } from 'react-router-dom'
import Modal from './modal'
import RegularFilterModal from './regular-filter-modal'

function FilterModal(props) {
  function renderBody() {
    const modalType = props.match.params.field || 'page'
    return <RegularFilterModal site={props.site} modalType={modalType} />
  }

  return (
    <Modal site={props.site} maxWidth="460px">
      {renderBody()}
    </Modal>
  )
}

export default withRouter(FilterModal)
