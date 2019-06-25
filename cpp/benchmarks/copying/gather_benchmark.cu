/*
 * Copyright (c) 2019, NVIDIA CORPORATION.
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

#include <benchmark/benchmark.h>

#include <cudf/copying.hpp>
#include <cudf/table.hpp>

#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <tests/utilities/column_wrapper.cuh>
#include <tests/utilities/cudf_test_fixtures.h>
#include <tests/utilities/cudf_test_utils.cuh>
#include <cudf/types.hpp>
#include <utilities/wrapper_types.hpp>

#include <random>
#include <algorithm>


template<class TypeParam, bool opt>
void gather_inverse(benchmark::State& state){
  const gdf_size_type source_size{(gdf_size_type)state.range(0)};
  const gdf_size_type destination_size{(gdf_size_type)state.range(0)};

  const gdf_size_type n_cols = (gdf_size_type)state.range(1);

  std::vector<cudf::test::column_wrapper<TypeParam>> v_src(
    n_cols,
    { source_size, 
      [](gdf_index_type row){ return static_cast<TypeParam>(row); },
      [](gdf_index_type row) { return true; }
    }
  );
  std::vector<gdf_column*> vp_src(n_cols);
  for(size_t i = 0; i < v_src.size(); i++){
    vp_src[i] = v_src[i].get();  
  }
  
  // Create gather_map that reverses order of source_column
  std::vector<gdf_index_type> host_gather_map(source_size);
  std::iota(host_gather_map.begin(), host_gather_map.end(), 0);
  std::reverse(host_gather_map.begin(), host_gather_map.end());
  thrust::device_vector<gdf_index_type> gather_map(host_gather_map);

  std::vector<cudf::test::column_wrapper<TypeParam>> v_dest(
    n_cols,
    { source_size, 
      [](gdf_index_type row){return static_cast<TypeParam>(row);},
      [](gdf_index_type row) { return true; }
    }
  );
  std::vector<gdf_column*> vp_dest (n_cols);
  for(size_t i = 0; i < v_src.size(); i++){
    vp_dest[i] = v_dest[i].get();  
  }
 
  cudf::table source_table{ vp_src };
  cudf::table destination_table{ vp_dest };

  for(auto _ : state){
    if(opt){
      cudf::opt::gather(&source_table, gather_map.data().get(), &destination_table);
    }else{
      cudf::gather(&source_table, gather_map.data().get(), &destination_table);
    }
  }
  
  state.SetBytesProcessed(
      static_cast<int64_t>(state.iterations())*state.range(0)*n_cols*2*sizeof(TypeParam));
}
BENCHMARK_TEMPLATE(gather_inverse,double,false)->RangeMultiplier(4)->Ranges({{1<<10,1<<26},{1,4}});
BENCHMARK_TEMPLATE(gather_inverse,double, true)->RangeMultiplier(4)->Ranges({{1<<10,1<<26},{1,4}});

template<class TypeParam, bool opt>
void gather_random_(benchmark::State& state){
  const gdf_size_type source_size{(gdf_size_type)state.range(0)};
  const gdf_size_type destination_size{(gdf_size_type)state.range(0)};
  
  const gdf_size_type n_cols = (gdf_size_type)state.range(1);

  std::vector<cudf::test::column_wrapper<TypeParam>> v_src(
    n_cols,
    { source_size, 
      [](gdf_index_type row){ return static_cast<TypeParam>(row); },
      [](gdf_index_type row) { return true; }
    }
  );
  std::vector<gdf_column*> vp_src (n_cols);
  for(size_t i = 0; i < v_src.size(); i++){
    vp_src[i] = v_src[i].get();  
  }
  
  // Create gather_map that reverses order of source_column
  std::vector<gdf_index_type> host_gather_map(source_size);
  std::iota(host_gather_map.begin(), host_gather_map.end(), 0);
  std::random_shuffle(host_gather_map.begin(), host_gather_map.end());
  
//  std::set<int> s;
//  for(int i = 0; i < 256; i++){
//    s.insert(host_gather_map[i] / 32);
//  }
//  printf("%lu\n", s.size());
  
  thrust::device_vector<gdf_index_type> gather_map(host_gather_map);

  std::vector<cudf::test::column_wrapper<TypeParam>> v_dest(
    n_cols,
    { source_size, 
      [](gdf_index_type row){return static_cast<TypeParam>(row);},
      [](gdf_index_type row) { return true; }
    }
  );
  std::vector<gdf_column*> vp_dest (n_cols);
  for(size_t i = 0; i < v_src.size(); i++){
    vp_dest[i] = v_dest[i].get();  
  }
 
  cudf::table source_table{ vp_src };
  cudf::table destination_table{ vp_dest };
  if(opt){
    cudf::opt::gather(&source_table, gather_map.data().get(), &destination_table);
  }else{
    cudf::gather(&source_table, gather_map.data().get(), &destination_table);
  }

  for(auto _ : state){
    if(opt){
      cudf::opt::gather(&source_table, gather_map.data().get(), &destination_table);
    }else{
      cudf::gather(&source_table, gather_map.data().get(), &destination_table);
    }
  }
  
  state.SetBytesProcessed(
      static_cast<int64_t>(state.iterations())*state.range(0)*n_cols*2*sizeof(TypeParam));
}
BENCHMARK_TEMPLATE(gather_random_,double,false)->RangeMultiplier(4)->Ranges({{1<<10,1<<26},{1,4}});
BENCHMARK_TEMPLATE(gather_random_,double, true)->RangeMultiplier(4)->Ranges({{1<<10,1<<26},{1,4}});

