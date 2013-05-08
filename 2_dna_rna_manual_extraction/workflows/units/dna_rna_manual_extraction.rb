require 'helpers/constant'
require 'workflows/units/shared_units'

# This script goes through the different steps 
# of the DNA+RNA manual extraction pipeline.

module Lims::Api::Examples
  module DnaRnaManualExtraction    

    include Constant
    include Constant::DnaRnaManualExtraction
    include SharedUnits

    private

    def dna_rna_manual_extraction_workflow
      parameters = assign_batch
      order_uuid = parameters[:order_uuid]
      order_update_url = parameters[:order_update_url]

      uuids = []
      2.times do
        API::new_step("Create new spin column")
        parameters = {:spin_column => {}}
        response = API::post(@root_json["spin_columns"]["actions"]["create"], parameters)
        uuids << {:read => response["spin_column"]["actions"]["read"], :type => "spin_column", :contents => "DNA", :uuid => response["spin_column"]["uuid"]}

        API::new_step("Create new tube")
        parameters = {:tube => {}}
        response = API::post(@root_json["tubes"]["actions"]["create"], parameters)
        uuids << {:read => response["tube"]["actions"]["read"], :type => "tube", :contents => "RNA+P", :uuid => response["tube"]["uuid"]}
      end

      barcode_values = []
      uuids.each do |e|
        API::new_step("Generate a new barcode")
        barcode_values << API::mock_barcode_generation(e[:type], e[:contents])          
      end

      uuids.each do |e|
        API::new_step("Add a barcode to #{e[:uuid]}")
        barcode(e[:uuid], barcode_values.shift)
        API::get(e[:read])
      end

      uuids.each do |e|
        API::new_step("Get the barcoded resource")
        API::get(e[:read])
      end

      API::new_step("Printer service")
      API::mock_printer_service

      result = search_orders_by_batch
      initial_tube_uuids = result[:source_tube_uuids_array]

      new_asset_uuids = [[uuids[0][:uuid], uuids[1][:uuid]], [uuids[2][:uuid], uuids[3][:uuid]]]
      new_asset_uuids.each do |uuid|
        API::new_step("Add the new spin column and new tube in the order and start each of them")
        parameters = parameters_for_adding_resources_in_order({
          ROLE_BINDING_SPIN_COLUMN_DNA => [uuid[0]],
          ROLE_BY_PRODUCT_TUBE_RNAP => [uuid[1]]})
        API::put(order_update_url, parameters)
      end

      transfer_uuids = [[initial_tube_uuids[0], uuids[0][:uuid], uuids[1][:uuid]], [initial_tube_uuids[1], uuids[2][:uuid], uuids[3][:uuid]]] 
      transfer_uuids.each do |uuid|
        API::new_step("Transfer from tube to spin column and tube")
        parameters = {:transfer_tubes_to_tubes => {:transfers => [
          {:source_uuid => uuid[0], :target_uuid => uuid[1], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_DNA}, 
          {:source_uuid => uuid[0], :target_uuid => uuid[2], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
        ]}}
        API::post(@root_json["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
      end
    

     # API::new_step("Create the search order by batch")
     # parameters = {:search => {:description => "search order by batch",
     #                           :model => "order",
     #                           :criteria => {:item => {:batch => @batch_uuid}}}}
     # search_response = API::post("searches", parameters)

     # API::new_step("Get the result orders")
     # result_url = search_response["search"]["actions"]["first"]
     # result_response = API::get(result_url)


     # API::new_step("Change the status of the order to pending")
     # parameters = {:event => :build}
     # API::put(order_uuid, parameters)

     # API::new_step("Change the status of the order to in_progress")
     # parameters = {:event => :start}
     # API::put(order_uuid, parameters)

#      API::new_step("Create new spin columns")
 #     binding_spin_column_dna_uuids = factory(:spin_column, 2)


     # results = search_orders_by_batch
     # order_uuids = results[:order_uuids]
     # source_tube_uuids_array = results[:source_tube_uuids_array]
     
     # order_nb = 0
     # order_uuids.zip(source_tube_uuids_array).each do |order_uuid, source_tube_uuids|
     #   order_nb += 1
     #   n_entries = source_tube_uuids.size

     #   API::new_order(order_nb)

     #   # =========================
     #   API::new_stage("Build and start the order")
     #   # =========================

     #   API::new_step("Change the status of the order to pending")
     #   parameters = {:event => :build}
     #   API::put(order_uuid, parameters)

     #   API::new_step("Change the status of the order to in_progress")
     #   parameters = {:event => :start}
     #   API::put(order_uuid, parameters)


     #   # ============================================
     #   API::new_stage("Create binding_spin_columns_dna spin columns. Create by_product_tube tubes. Transfers from tube_to_be_extracted into binding_spin_column_dna and by_product_tube tubes.") 
     #   # ============================================

     #   API::new_step("Create new spin columns")
     #   binding_spin_column_dna_uuids = factory(:spin_column, n_entries)

     #   API::new_step("Create new tubes ")
     #   by_product_tube_uuids = factory(:tube, n_entries) 

     #   API::new_step("Add the new spin columns and new tubes in the order and start each of them")
     #   parameters = parameters_for_adding_resources_in_order({
     #     ROLE_BINDING_SPIN_COLUMN_DNA => binding_spin_column_dna_uuids,
     #     ROLE_BY_PRODUCT_TUBE_RNAP => by_product_tube_uuids})
     #   API::put(order_uuid, parameters)

     #   API::new_step("Transfers from tube_to_be_extracted into binding_spin_column_dna spins and into by_product_tube tubes.")
     #   parameters = parameters_for_transfer([
     #     {:source => source_tube_uuids, :target => binding_spin_column_dna_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_DNA},
     #     {:source => source_tube_uuids, :target => by_product_tube_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
     #   ])
     #   API::post("actions/transfer_tubes_to_tubes", parameters)

     #   API::new_step("Change the status of the binding_spin_column_dna to done. Change the status of the by_product_tube to done. Change the status of the tube_to_be_extracted to unused")
     #   parameters = parameters_for_changing_items_status({
     #     ROLE_BINDING_SPIN_COLUMN_DNA => {:uuids => binding_spin_column_dna_uuids, :event => :complete},
     #     ROLE_BY_PRODUCT_TUBE_RNAP => {:uuids => by_product_tube_uuids, :event => :complete},
     #     ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => {:uuids => source_tube_uuids, :event => :unuse}
     #   })
     #   API::put(order_uuid, parameters)


     #   # ==============================================
     #   API::new_stage("Transfer the content of the spin columns to new extracted_tube tubes.")
     #   # ==============================================

     #   #API::new_step("Add the binding_spin_column_dna under the role elution_spin_column_dna and start them.")
     #   #elution_spin_column_dna_uuids = binding_spin_column_dna_uuids # alias
     #   #parameters = parameters_for_adding_resources_in_order(ROLE_ELUTION_SPIN_COLUMN_DNA => elution_spin_column_dna_uuids)
     #   #API::put(order_uuid, parameters)

     #   #API::new_step("Change the status of elution_spin_column_dna to done. Change the status of binding_spin_column_dna to unused ")
     #   #parameters = parameters_for_changing_items_status({
     #   #  ROLE_ELUTION_SPIN_COLUMN_DNA => {:uuids => elution_spin_column_dna_uuids, :event => :complete},
     #   #  ROLE_BINDING_SPIN_COLUMN_DNA => {:uuids => binding_spin_column_dna_uuids, :event => :unuse}
     #   #})
     #   #API::put(order_uuid, parameters)

     #   API::new_step("Create new tubes ")
     #   extracted_tube_dna_uuids = factory(:tube, n_entries)

     #   API::new_step("Add the extracted_dna_tube in the order and start them")
     #   parameters = parameters_for_adding_resources_in_order(ROLE_EXTRACTED_TUBE_DNA => extracted_tube_dna_uuids)
     #   API::put(order_uuid, parameters)

     #   API::new_step("Transfer binding_spin_column_dna into extracted_tube")
     #   parameters = parameters_for_transfer([{:source => binding_spin_column_dna_uuids, :target => extracted_tube_dna_uuids, :fraction => 1}])
     #   API::post("actions/transfer_tubes_to_tubes", parameters)

     #   API::new_step("Change the status of extracted_tube tubes to done. Change the status of binding_spin_column_dna to unused")
     #   parameters = parameters_for_changing_items_status({
     #     ROLE_EXTRACTED_TUBE_DNA => {:uuids => extracted_tube_dna_uuids, :event => :complete},
     #     ROLE_BINDING_SPIN_COLUMN_DNA => {:uuids => binding_spin_column_dna_uuids, :event => :unuse}
     #   })
     #   API::put(order_uuid, parameters)


     #   # =====================================
     #   API::new_stage("Create new tube_to_be_extracted tube. Transfer from by_product_tube into tube_to_be_extracted.")
     #   # =====================================

     #   API::new_step("Create new tubes ")
     #   tube_to_be_extracted_uuids = factory(:tube, n_entries)

     #   API::new_step("Add tube_to_be_extracted tubes in the order and start them.")
     #   parameters = parameters_for_adding_resources_in_order(ROLE_TUBE_TO_BE_EXTRACTED_RNAP => tube_to_be_extracted_uuids)
     #   API::put(order_uuid, parameters)

     #   API::new_step("Transfer from by_product_tube tubes into tube_to_be_extracted tubes")
     #   parameters = parameters_for_transfer([{:source => by_product_tube_uuids, :target => tube_to_be_extracted_uuids, :fraction => 1}])
     #   API::post("actions/transfer_tubes_to_tubes", parameters)

     #   API::new_step("Change the status of by_product_tube to done. Change the status of tube_to_be_extracted to done")
     #   parameters = parameters_for_changing_items_status({
     #     ROLE_TUBE_TO_BE_EXTRACTED_RNAP => {:uuids => tube_to_be_extracted_uuids, :event => :complete},
     #     ROLE_BY_PRODUCT_TUBE_RNAP => {:uuids => by_product_tube_uuids, :event => :unuse}
     #   })
     #   API::put(order_uuid, parameters)


     #   # =============================================
     #   API::new_stage("Create binding_spin_column_rna spins. Create by_product_tube tubes. Transfer tube_to_be_extracted into binding_spin_column_rna and into by_product_tube.")
     #   # =============================================

     #   API::new_step("Create new spin columns")
     #   binding_spin_column_rna_uuids = factory(:spin_column, n_entries)

     #   API::new_step("Create new tubes ")
     #   by_product_tube_uuids = factory(:tube, n_entries)

     #   API::new_step("Add the new spin columns and new tubes in the order and start each of them")
     #   parameters = parameters_for_adding_resources_in_order({ROLE_BINDING_SPIN_COLUMN_RNA => binding_spin_column_rna_uuids,
     #                                                          ROLE_BY_PRODUCT_TUBE_RNAP => by_product_tube_uuids})
     #   API::put(order_uuid, parameters)

     #   API::new_step("Transfers from tube_to_be_extracted into binding_spin_column_rna spins and into by_product_tube tubes.")
     #   parameters = parameters_for_transfer([
     #     {:source => tube_to_be_extracted_uuids, :target => binding_spin_column_rna_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNA},
     #     {:source => tube_to_be_extracted_uuids, :target => by_product_tube_uuids, :fraction => 0.5}
     #   ])
     #   API::post("actions/transfer_tubes_to_tubes", parameters)

     #   API::new_step("Change the status of binding_spin_column_rna to done. Change the status of by_product_tube to done. Change the status of tube_to_be_extracted to unused")
     #   parameters = parameters_for_changing_items_status({
     #     ROLE_BINDING_SPIN_COLUMN_RNA => {:uuids => binding_spin_column_rna_uuids, :event => :complete},
     #     ROLE_BY_PRODUCT_TUBE_RNAP => {:uuids => by_product_tube_uuids, :event => :complete},
     #     ROLE_TUBE_TO_BE_EXTRACTED_RNAP => {:uuids => tube_to_be_extracted_uuids, :event => :unuse}
     #   })
     #   API::put(order_uuid, parameters)


     #   # ==============================================
     #   API::new_stage("Transfer the content of the spin columns to new extracted_tube tubes.")
     #   # ==============================================

     #   #API::new_step("Add the binding_spin_column_rna under the role elution_spin_column_rna and start them.")
     #   #elution_spin_column_rna_uuids = binding_spin_column_rna_uuids # alias
     #   #parameters = parameters_for_adding_resources_in_order(ROLE_ELUTION_SPIN_COLUMN_RNA => elution_spin_column_rna_uuids)
     #   #API::put(order_uuid, parameters)

     #   #API::new_step("Change the status of elution_spin_column_rna to done. Change the status of binding_spin_column_rna to unused ")
     #   #parameters = parameters_for_changing_items_status({
     #   #  ROLE_ELUTION_SPIN_COLUMN_RNA => {:uuids => elution_spin_column_rna_uuids, :event => :complete},
     #   #  ROLE_BINDING_SPIN_COLUMN_RNA => {:uuids => binding_spin_column_rna_uuids, :event => :unuse}
     #   #})
     #   #API::put(order_uuid, parameters)

     #   API::new_step("Create new tubes ")
     #   extracted_tube_rna_uuids = factory(:tube, n_entries)

     #   API::new_step("Add the extracted_rna_tube in the order and start them")
     #   parameters = parameters_for_adding_resources_in_order(ROLE_EXTRACTED_TUBE_RNA => extracted_tube_rna_uuids)
     #   API::put(order_uuid, parameters)

     #   API::new_step("Transfer binding_spin_column_rna into extracted_tube")
     #   parameters = parameters_for_transfer([{:source => binding_spin_column_rna_uuids, :target => extracted_tube_rna_uuids, :fraction => 1}])
     #   API::post("actions/transfer_tubes_to_tubes", parameters)

     #   API::new_step("Change the status of extracted_tube tubes to done. Change the status of binding_spin_column_rna to unused")
     #   parameters = parameters_for_changing_items_status({
     #     ROLE_EXTRACTED_TUBE_RNA => {:uuids => extracted_tube_rna_uuids, :event => :complete},
     #     ROLE_BINDING_SPIN_COLUMN_RNA => {:uuids => binding_spin_column_rna_uuids, :event => :unuse}
     #   })
     #   API::put(order_uuid, parameters)


     #   # Pass parameters needed to continue the workflow in
     #   # post extraction tube racking
     #   @parameters[:post_extraction] ||= {}
     #   @parameters[:post_extraction][order_nb] = {:order_uuid => order_uuid, 
     #                  :batch_uuid => batch_uuid,
     #                  :extracted_tube_uuids => {:RNA => extracted_tube_rna_uuids,
     #                                            :DNA => extracted_tube_dna_uuids}}
     # end
    end
  end
end
