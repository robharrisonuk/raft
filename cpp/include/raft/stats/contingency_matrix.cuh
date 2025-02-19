/*
 * Copyright (c) 2019-2022, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __CONTINGENCY_MATRIX_H
#define __CONTINGENCY_MATRIX_H

#pragma once

#include <raft/core/device_mdarray.hpp>
#include <raft/core/device_mdspan.hpp>
#include <raft/core/handle.hpp>
#include <raft/core/host_mdspan.hpp>
#include <raft/stats/detail/contingencyMatrix.cuh>

namespace raft {
namespace stats {

/**
 * @brief use this to allocate output matrix size
 * size of matrix = (maxLabel - minLabel + 1)^2 * sizeof(int)
 * @param groundTruth: device 1-d array for ground truth (num of rows)
 * @param nSamples: number of elements in input array
 * @param stream: cuda stream for execution
 * @param minLabel: [out] calculated min value in input array
 * @param maxLabel: [out] calculated max value in input array
 */
template <typename T>
void getInputClassCardinality(
  const T* groundTruth, const int nSamples, cudaStream_t stream, T& minLabel, T& maxLabel)
{
  detail::getInputClassCardinality(groundTruth, nSamples, stream, minLabel, maxLabel);
}

/**
 * @brief use this to allocate output matrix size
 * size of matrix = (maxLabel - minLabel + 1)^2 * sizeof(int)
 * @tparam value_t label type
 * @tparam idx_t Index type of matrix extent.
 * @param[in]  handle: the raft handle.
 * @param[in]  groundTruth: device 1-d array for ground truth (num of rows)
 * @param[out] minLabel: calculated min value in input array
 * @param[out] maxLabel: calculated max value in input array
 */
template <typename value_t, typename idx_t>
void get_input_class_cardinality(const raft::handle_t& handle,
                                 raft::device_vector_view<const value_t, idx_t> groundTruth,
                                 raft::host_scalar_view<value_t> minLabel,
                                 raft::host_scalar_view<value_t> maxLabel)
{
  RAFT_EXPECTS(minLabel.data_handle() != nullptr, "Invalid minLabel pointer");
  RAFT_EXPECTS(maxLabel.data_handle() != nullptr, "Invalid maxLabel pointer");
  detail::getInputClassCardinality(groundTruth.data_handle(),
                                   groundTruth.extent(0),
                                   handle.get_stream(),
                                   *minLabel.data_handle(),
                                   *maxLabel.data_handle());
}

/**
 * @brief Calculate workspace size for running contingency matrix calculations
 * @tparam T label type
 * @tparam OutT output matrix type
 * @param nSamples: number of elements in input array
 * @param groundTruth: device 1-d array for ground truth (num of rows)
 * @param stream: cuda stream for execution
 * @param minLabel: Optional, min value in input array
 * @param maxLabel: Optional, max value in input array
 */
template <typename T, typename OutT = int>
size_t getContingencyMatrixWorkspaceSize(int nSamples,
                                         const T* groundTruth,
                                         cudaStream_t stream,
                                         T minLabel = std::numeric_limits<T>::max(),
                                         T maxLabel = std::numeric_limits<T>::max())
{
  return detail::getContingencyMatrixWorkspaceSize(
    nSamples, groundTruth, stream, minLabel, maxLabel);
}

/**
 * @brief contruct contingency matrix given input ground truth and prediction
 *        labels. Users should call function getInputClassCardinality to find
 *        and allocate memory for output. Similarly workspace requirements
 *        should be checked using function getContingencyMatrixWorkspaceSize
 * @tparam T label type
 * @tparam OutT output matrix type
 * @param groundTruth: device 1-d array for ground truth (num of rows)
 * @param predictedLabel: device 1-d array for prediction (num of columns)
 * @param nSamples: number of elements in input array
 * @param outMat: output buffer for contingency matrix
 * @param stream: cuda stream for execution
 * @param workspace: Optional, workspace memory allocation
 * @param workspaceSize: Optional, size of workspace memory
 * @param minLabel: Optional, min value in input ground truth array
 * @param maxLabel: Optional, max value in input ground truth array
 */
template <typename T, typename OutT = int>
void contingencyMatrix(const T* groundTruth,
                       const T* predictedLabel,
                       int nSamples,
                       OutT* outMat,
                       cudaStream_t stream,
                       void* workspace      = nullptr,
                       size_t workspaceSize = 0,
                       T minLabel           = std::numeric_limits<T>::max(),
                       T maxLabel           = std::numeric_limits<T>::max())
{
  detail::contingencyMatrix<T, OutT>(groundTruth,
                                     predictedLabel,
                                     nSamples,
                                     outMat,
                                     stream,
                                     workspace,
                                     workspaceSize,
                                     minLabel,
                                     maxLabel);
}

/**
 * @brief contruct contingency matrix given input ground truth and prediction
 *        labels. Users should call function getInputClassCardinality to find
 *        and allocate memory for output. Similarly workspace requirements
 *        should be checked using function getContingencyMatrixWorkspaceSize
 * @tparam value_t label type
 * @tparam out_t output matrix type
 * @tparam idx_t Index type of matrix extent.
 * @tparam layout_t Layout type of the input data.
 * @param[in]  handle: the raft handle.
 * @param[in]  ground_truth: device 1-d array for ground truth (num of rows)
 * @param[in]  predicted_label: device 1-d array for prediction (num of columns)
 * @param[out] out_mat: output buffer for contingency matrix
 * @param[in]  min_label: Optional, min value in input ground truth array
 * @param[in]  max_label: Optional, max value in input ground truth array
 */
template <typename value_t, typename out_t, typename idx_t, typename layout_t>
void contingency_matrix(const raft::handle_t& handle,
                        raft::device_vector_view<const value_t, idx_t> ground_truth,
                        raft::device_vector_view<const value_t, idx_t> predicted_label,
                        raft::device_matrix_view<out_t, idx_t, layout_t> out_mat,
                        std::optional<value_t> min_label = std::nullopt,
                        std::optional<value_t> max_label = std::nullopt)
{
  RAFT_EXPECTS(ground_truth.size() == predicted_label.size(), "Size mismatch");
  RAFT_EXPECTS(ground_truth.is_exhaustive(), "ground_truth must be contiguous");
  RAFT_EXPECTS(predicted_label.is_exhaustive(), "predicted_label must be contiguous");
  RAFT_EXPECTS(out_mat.is_exhaustive(), "out_mat must be contiguous");

  value_t min_label_value = std::numeric_limits<value_t>::max();
  value_t max_label_value = std::numeric_limits<value_t>::max();
  if (min_label.has_value()) { min_label_value = min_label.value(); }
  if (max_label.has_value()) { max_label_value = max_label.value(); }

  auto workspace_sz = detail::getContingencyMatrixWorkspaceSize(ground_truth.extent(0),
                                                                ground_truth.data_handle(),
                                                                handle.get_stream(),
                                                                min_label_value,
                                                                max_label_value);
  auto workspace    = raft::make_device_vector<char>(handle, workspace_sz);

  detail::contingencyMatrix<value_t, out_t>(ground_truth.data_handle(),
                                            predicted_label.data_handle(),
                                            ground_truth.extent(0),
                                            out_mat.data_handle(),
                                            handle.get_stream(),
                                            workspace.data_handle(),
                                            workspace_sz,
                                            min_label_value,
                                            max_label_value);
}

/**
 * @brief Overload of `contingency_matrix` to help the
 *   compiler find the above overload, in case users pass in
 *   `std::nullopt` for the optional arguments.
 *
 * Please see above for documentation of `contingency_matrix`.
 */
template <typename value_t,
          typename out_t,
          typename idx_t,
          typename layout_t,
          typename opt_min_label_t,
          typename opt_max_label_t>
void contingency_matrix(const raft::handle_t& handle,
                        raft::device_vector_view<const value_t, idx_t> ground_truth,
                        raft::device_vector_view<const value_t, idx_t> predicted_label,
                        raft::device_matrix_view<out_t, idx_t, layout_t> out_mat,
                        opt_min_label_t&& min_label = std::nullopt,
                        opt_max_label_t&& max_label = std::nullopt)
{
  std::optional<value_t> opt_min_label = std::forward<opt_min_label_t>(min_label);
  std::optional<value_t> opt_max_label = std::forward<opt_max_label_t>(max_label);
  contingency_matrix(handle, ground_truth, predicted_label, out_mat, opt_min_label, opt_max_label);
}
};  // namespace stats
};  // namespace raft

#endif