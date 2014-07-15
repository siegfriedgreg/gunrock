#pragma once
#include <gunrock/util/basic_utils.cuh>
#include <gunrock/util/cuda_properties.cuh>
#include <gunrock/util/cta_work_distribution.cuh>
#include <gunrock/util/soa_tuple.cuh>
#include <gunrock/util/srts_grid.cuh>
#include <gunrock/util/srts_soa_details.cuh>
#include <gunrock/util/io/modified_load.cuh>
#include <gunrock/util/io/modified_store.cuh>
#include <gunrock/util/operators.cuh>

#include <gunrock/util/test_utils.cuh>

#include <gunrock/app/problem_base.cuh>
#include <gunrock/app/enactor_base.cuh>

#include <gunrock/util/cta_work_distribution.cuh>
#include <gunrock/util/cta_work_progress.cuh>
#include <gunrock/util/kernel_runtime_stats.cuh>

//#include <gunrock/oprtr/edge_map_forward/kernel.cuh>
#include <gunrock/oprtr/edge_map_partitioned_backward/kernel.cuh>
#include <gunrock/oprtr/edge_map_partitioned/kernel.cuh>

#include <gunrock/oprtr/advance/kernel_policy.cuh>
#include <gunrock/util/multithread_utils.cuh>

#include <moderngpu.cuh>

namespace gunrock {
namespace oprtr {
namespace advance {

template<typename KernelPolicy, typename ProblemData, typename Functor>
unsigned int ComputeOutputLength(
                                    int                             num_block,
                                    gunrock::app::FrontierAttribute &frontier_attribute,
                                    typename KernelPolicy::SizeT    *d_offsets,
                                    typename KernelPolicy::VertexId *d_indices,
                                    typename KernelPolicy::VertexId *d_in_key_queue,
                                    unsigned int                    *partitioned_scanned_edges,
                                    typename KernelPolicy::SizeT    max_in,
                                    typename KernelPolicy::SizeT    max_out,
                                    CudaContext                     &context,
                                    TYPE                            ADVANCE_TYPE) {

    typedef typename ProblemData::SizeT         SizeT;

    gunrock::oprtr::edge_map_partitioned::GetEdgeCounts<KernelPolicy, ProblemData, Functor>
        <<< num_block, KernelPolicy::THREADS >>>(
                d_offsets,
                d_indices,
                d_in_key_queue,
                partitioned_scanned_edges,
                frontier_attribute.queue_length,
                max_in,
                max_out,
                ADVANCE_TYPE);

    Scan<mgpu::MgpuScanTypeInc>((int*)partitioned_scanned_edges, frontier_attribute.queue_length, (int)0, mgpu::plus<int>(),
            (int*)0, (int*)0, (int*)partitioned_scanned_edges, context);

    SizeT *temp = new SizeT[1];
    cudaMemcpy(temp,partitioned_scanned_edges+frontier_attribute.queue_length-1, sizeof(SizeT), cudaMemcpyDeviceToHost);
    SizeT ret = temp[0];
    delete[] temp;
    return ret;
}

//TODO: finish LaucnKernel, should load diferent kernels according to their AdvanceMode
//AdvanceType is the argument to send into each kernel call
template <typename KernelPolicy, typename ProblemData, typename Functor>
    void LaunchKernel(
            volatile int                            *d_done,
            gunrock::app::EnactorStats              &enactor_stats,
            gunrock::app::FrontierAttribute         &frontier_attribute,
            typename ProblemData::DataSlice         *data_slice,
            typename ProblemData::VertexId          *backward_index_queue,
            bool                                    *backward_frontier_map_in,
            bool                                    *backward_frontier_map_out,
            unsigned int                            *partitioned_scanned_edges,
            typename KernelPolicy::VertexId         *d_in_key_queue,
            typename KernelPolicy::VertexId         *d_out_key_queue,
            typename KernelPolicy::VertexId         *d_in_value_queue,
            typename KernelPolicy::VertexId         *d_out_value_queue,
            typename KernelPolicy::SizeT            *d_row_offsets,
            typename KernelPolicy::VertexId         *d_column_indices,
            typename KernelPolicy::SizeT            *d_column_offsets,
            typename KernelPolicy::VertexId         *d_row_indices,
            typename KernelPolicy::SizeT            max_in,
            typename KernelPolicy::SizeT            max_out,
            util::CtaWorkProgress                   work_progress,
            CudaContext                             &context,
            TYPE                                    ADVANCE_TYPE,
            bool                                    inverse_graph = false,
            bool                                    get_output_length = true)
{
    if (frontier_attribute.queue_length == 0) return;
    switch (KernelPolicy::ADVANCE_MODE)
    {
        /*case TWC_FORWARD:
        {
            // Load Thread Warp CTA Forward Kernel
            gunrock::oprtr::edge_map_forward::Kernel<typename KernelPolicy::THREAD_WARP_CTA_FORWARD, ProblemData, Functor>
                <<<enactor_stats.advance_grid_size, KernelPolicy::THREAD_WARP_CTA_FORWARD::THREADS>>>(
                    frontier_attribute.queue_reset,
                    frontier_attribute.queue_index,
                    1,//enactor_stats.num_gpus,
                    enactor_stats.iteration,
                    frontier_attribute.queue_length,
                    d_done,
                    d_in_key_queue,              // d_in_queue
                    d_out_value_queue,          // d_pred_out_queue
                    d_out_key_queue,            // d_out_queue
                    d_column_indices,
                    d_row_indices,
                    data_slice,
                    work_progress,
                    max_in,                   // max_in_queue
                    max_out,                 // max_out_queue
                    enactor_stats.advance_kernel_stats,
                    NULL,
                    NULL,
                    ADVANCE_TYPE,
                    inverse_graph);
            break;
        }*/
        case TWC_BACKWARD:
        {
            // Load Thread Warp CTA Backward Kernel
            typedef typename ProblemData::SizeT         SizeT;
            typedef typename ProblemData::VertexId      VertexId;
            typedef typename KernelPolicy::LOAD_BALANCED LBPOLICY;
            // Load Load Balanced Kernel
            // Get Rowoffsets
            // Use scan to compute edge_offsets for each vertex in the frontier
            // Use sorted sort to compute partition bound for each work-chunk
            // load edge-expand-partitioned kernel
            //util::DisplayDeviceResults(d_in_key_queue, frontier_attribute.queue_length);
            int num_block = (frontier_attribute.queue_length + KernelPolicy::LOAD_BALANCED::THREADS - 1)/KernelPolicy::LOAD_BALANCED::THREADS;
            /*gunrock::oprtr::edge_map_partitioned_backward::GetEdgeCounts<typename KernelPolicy::LOAD_BALANCED, ProblemData, Functor>
            <<< num_block, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                                        d_column_offsets,
                                        d_row_indices,
                                        d_in_key_queue,
                                        partitioned_scanned_edges,
                                        frontier_attribute.queue_length,
                                        max_in,
                                        max_out,
                                        ADVANCE_TYPE);

            Scan<mgpu::MgpuScanTypeInc>((int*)partitioned_scanned_edges, frontier_attribute.queue_length, (int)0, mgpu::plus<int>(),
            (int*)0, (int*)0, (int*)partitioned_scanned_edges, context);

            SizeT *temp = new SizeT[1];
            cudaMemcpy(temp,partitioned_scanned_edges+frontier_attribute.queue_length-1, sizeof(SizeT), cudaMemcpyDeviceToHost);
            SizeT output_queue_len = temp[0];*/
            //printf("input queue:%d, output_queue:%d\n", frontier_attribute.queue_length, frontier_attribute.output_length); 
            if (get_output_length)
                frontier_attribute.output_length = ComputeOutputLength<LBPOLICY, ProblemData, Functor>(
                                    num_block,
                                    frontier_attribute,
                                    d_column_offsets,
                                    d_row_indices,
                                    d_in_key_queue,
                                    partitioned_scanned_edges,
                                    max_in,
                                    max_out,
                                    context,
                                    ADVANCE_TYPE);

            if (frontier_attribute.selector == 1) {
                // Edge Map
                gunrock::oprtr::edge_map_partitioned_backward::RelaxLightEdges<LBPOLICY, ProblemData, Functor>
                <<< num_block, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                        frontier_attribute.queue_reset,
                        frontier_attribute.queue_index,
                        enactor_stats.iteration,
                        d_column_offsets,
                        d_row_indices,
                        (VertexId*)NULL,
                        partitioned_scanned_edges,
                        d_done,
                        d_in_key_queue,
                        backward_frontier_map_in,
                        backward_frontier_map_out,
                        data_slice,
                        frontier_attribute.queue_length,
                        frontier_attribute.output_length,
                        max_in,
                        max_out,
                        work_progress,
                        enactor_stats.advance_kernel_stats,
                        ADVANCE_TYPE,
                        inverse_graph);
            } else {
                // Edge Map
                gunrock::oprtr::edge_map_partitioned_backward::RelaxLightEdges<LBPOLICY, ProblemData, Functor>
                <<< num_block, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                        frontier_attribute.queue_reset,
                        frontier_attribute.queue_index,
                        enactor_stats.iteration,
                        d_column_offsets,
                        d_row_indices,
                        (VertexId*)NULL,
                        partitioned_scanned_edges,
                        d_done,
                        d_in_key_queue,
                        backward_frontier_map_out,
                        backward_frontier_map_in,
                        data_slice,
                        frontier_attribute.queue_length,
                        frontier_attribute.output_length,
                        max_in,
                        max_out,
                        work_progress,
                        enactor_stats.advance_kernel_stats,
                        ADVANCE_TYPE,
                        inverse_graph);
            }
            break;
        }
        case LB:
        {
            typedef typename ProblemData::SizeT         SizeT;
            typedef typename ProblemData::VertexId      VertexId;
            typedef typename KernelPolicy::LOAD_BALANCED LBPOLICY;
            // Load Load Balanced Kernel
            // Get Rowoffsets
            // Use scan to compute edge_offsets for each vertex in the frontier
            // Use sorted sort to compute partition bound for each work-chunk
            // load edge-expand-partitioned kernel
            int num_block = (frontier_attribute.queue_length + KernelPolicy::LOAD_BALANCED::THREADS - 1)/KernelPolicy::LOAD_BALANCED::THREADS;
            /*gunrock::oprtr::edge_map_partitioned::GetEdgeCounts<typename KernelPolicy::LOAD_BALANCED, ProblemData, Functor>
            <<< num_block, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                                        d_row_offsets,
                                        d_column_indices,
                                        d_in_key_queue,
                                        partitioned_scanned_edges,
                                        frontier_attribute.queue_length,
                                        max_in,
                                        max_out,
                                        ADVANCE_TYPE);
            //util::cpu_mt::PrintGPUArray<SizeT, int>("pse",(int*)partitioned_scanned_edges,frontier_attribute.queue_length);
            Scan<mgpu::MgpuScanTypeInc>((int*)partitioned_scanned_edges, frontier_attribute.queue_length, (int)0, mgpu::plus<int>(),
            (int*)0, (int*)0, (int*)partitioned_scanned_edges, context);

            SizeT *temp = new SizeT[1];
            cudaMemcpy(temp,partitioned_scanned_edges+frontier_attribute.queue_length-1, sizeof(SizeT), cudaMemcpyDeviceToHost);
            SizeT output_queue_len = temp[0];*/

            if (get_output_length)
                frontier_attribute.output_length = ComputeOutputLength<LBPOLICY, ProblemData, Functor>(
                                    num_block,
                                    frontier_attribute,
                                    d_row_offsets,
                                    d_column_indices,
                                    d_in_key_queue,
                                    partitioned_scanned_edges,
                                    max_in,
                                    max_out,
                                    context,
                                    ADVANCE_TYPE);
            //printf("input_queue_len:%d\n", frontier_attribute.queue_length);
            //printf("output_queue_len:%d\n", output_queue_len);


            //if (frontier_attribute.output_length < LBPOLICY::LIGHT_EDGE_THRESHOLD)
            {
                gunrock::oprtr::edge_map_partitioned::RelaxLightEdges<LBPOLICY, ProblemData, Functor>
                <<< num_block, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                        frontier_attribute.queue_reset,
                        frontier_attribute.queue_index,
                        enactor_stats.iteration,
                        d_row_offsets,
                        d_column_indices,
                        d_row_indices,
                        partitioned_scanned_edges,
                        d_done,
                        d_in_key_queue,
                        d_out_key_queue,
                        data_slice,
                        frontier_attribute.queue_length,
                        frontier_attribute.output_length,
                        max_in,
                        max_out,
                        work_progress,
                        enactor_stats.advance_kernel_stats,
                        ADVANCE_TYPE,
                        inverse_graph);
            }
            /*else
            {
                unsigned int split_val = (frontier_attribute.output_length + KernelPolicy::LOAD_BALANCED::BLOCKS - 1) / KernelPolicy::LOAD_BALANCED::BLOCKS;
                util::MemsetIdxKernel<<<128, 128>>>(enactor_stats.d_node_locks, KernelPolicy::LOAD_BALANCED::BLOCKS, split_val);
                SortedSearch<MgpuBoundsLower>(
                enactor_stats.d_node_locks,
                KernelPolicy::LOAD_BALANCED::BLOCKS,
                partitioned_scanned_edges,
                frontier_attribute.queue_length,
                enactor_stats.d_node_locks_out,
                context);

                //util::DisplayDeviceResults(enactor_stats.d_node_locks_out, KernelPolicy::LOAD_BALANCED::BLOCKS);

                gunrock::oprtr::edge_map_partitioned::RelaxPartitionedEdges<typename KernelPolicy::LOAD_BALANCED, ProblemData, Functor>
                <<< KernelPolicy::LOAD_BALANCED::BLOCKS, KernelPolicy::LOAD_BALANCED::THREADS >>>(
                                        frontier_attribute.queue_reset,
                                        frontier_attribute.queue_index,
                                        enactor_stats.iteration,
                                        d_row_offsets,
                                        d_column_indices,
                                        d_row_indices,
                                        partitioned_scanned_edges,
                                        enactor_stats.d_node_locks_out,
                                        KernelPolicy::LOAD_BALANCED::BLOCKS,
                                        d_done,
                                        d_in_key_queue,
                                        d_out_key_queue,
                                        data_slice,
                                        frontier_attribute.queue_length,
                                        frontier_attribute.output_length,
                                        split_val,
                                        max_in,
                                        max_out,
                                        work_progress,
                                        enactor_stats.advance_kernel_stats,
                                        ADVANCE_TYPE,
                                        inverse_graph);
            }*/
            break;
        }
    }
}


} //advance
} //oprtr
} //gunrock/
