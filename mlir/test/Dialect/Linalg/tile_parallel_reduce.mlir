// RUN: mlir-opt %s -linalg-tile-to-parallel-loops="linalg-tile-sizes=2,4,8" -split-input-file | FileCheck %s
// RUN: mlir-opt %s -linalg-tile-to-parallel-loops="linalg-tile-sizes=2" -split-input-file | FileCheck %s -check-prefix=TILE1
// RUN: mlir-opt %s -linalg-tile-to-parallel-loops="linalg-tile-sizes=2,4" -split-input-file | FileCheck %s -check-prefix=TILE2

func @gemm(%arg0 : memref<?x?xf32>,
           %arg1 : memref<?x?xf32>,
           %arg2 : memref<?x?xf32>)
{
  linalg.matmul ins(%arg0, %arg1: memref<?x?xf32>, memref<?x?xf32>)
               outs(%arg2: memref<?x?xf32>)
  return
}
// CHECK-LABEL: func @gemm
//   CHECK-DAG:   %[[C2:.*]] = constant 2 : index
//   CHECK-DAG:   %[[C4:.*]] = constant 4 : index
//   CHECK-DAG:   %[[C8:.*]] = constant 8 : index
//       CHECK:   scf.parallel (%[[ARG3:.*]], %[[ARG4:.*]]) =
//  CHECK-SAME:     step (%[[C2]], %[[C4]])
//       CHECK:     scf.for %[[ARG5:.*]] =
//  CHECK-SAME:       step %[[C8]]
//       CHECK:       %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG5]]]
//       CHECK:       %[[SV2:.*]] = subview %{{.*}}[%[[ARG5]], %[[ARG4]]]
//       CHECK:       %[[SV3:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG4]]]
//       CHECK:       linalg.matmul ins(%[[SV1]], %[[SV2]]{{.*}} outs(%[[SV3]]

// TILE1-LABEL: func @gemm
//   TILE1-DAG:   %[[C2:.*]] = constant 2 : index
//       TILE1:   scf.parallel (%[[ARG3:.*]]) =
//  TILE1-SAME:     step (%[[C2]])
//       TILE1:     %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], 0]
//       TILE1:     %[[SV3:.*]] = subview %{{.*}}[%[[ARG3]], 0]
//   TILE1-NOT:     subview
//       TILE1:     linalg.matmul ins(%[[SV1]], %{{.*}} outs(%[[SV3]]

// TILE2-LABEL: func @gemm
//   TILE2-DAG:   %[[C2:.*]] = constant 2 : index
//   TILE2-DAG:   %[[C4:.*]] = constant 4 : index
//       TILE2:   scf.parallel (%[[ARG3:.*]], %[[ARG4:.*]]) =
//  TILE2-SAME:     step (%[[C2]], %[[C4]])
//       TILE2:       %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], 0]
//       TILE2:       %[[SV2:.*]] = subview %{{.*}}[0, %[[ARG4]]]
//       TILE2:       %[[SV3:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG4]]]
//       TILE2:       linalg.matmul ins(%[[SV1]], %[[SV2]]{{.*}} outs(%[[SV3]]

// -----

#map0 = affine_map<(d0, d1, d2) -> (d0, d1, d2)>
#map1 = affine_map<(d0, d1, d2) -> (d0, d2)>
#map2 = affine_map<(d0, d1, d2) -> (d1)>
#accesses = [#map0, #map1, #map2]
#trait = {
  args_in = 2 : i64,
  args_out = 1 : i64,
  iterator_types = ["reduction", "parallel", "reduction"],
  indexing_maps = #accesses
}

func @reduction(%arg0 : memref<?x?x?xf32>,
                %arg1 : memref<?x?xf32>,
                %arg2 : memref<?xf32>)
{
  linalg.generic #trait %arg0, %arg1, %arg2 {
  ^bb0(%arg3 : f32, %arg4 : f32, %arg5 : f32):
    %0 = addf %arg3, %arg4 : f32
    %1 = addf %0, %arg5 : f32
    linalg.yield %1 : f32
  } : memref<?x?x?xf32>, memref<?x?xf32>, memref<?xf32>
  return
}

// CHECK-LABEL: func @reduction
//   CHECK-DAG:   %[[C2:.*]] = constant 2 : index
//   CHECK-DAG:   %[[C4:.*]] = constant 4 : index
//   CHECK-DAG:   %[[C8:.*]] = constant 8 : index
//       CHECK:   scf.for %[[ARG3:.*]] =
//  CHECK-SAME:     step %[[C2]]
//       CHECK:     scf.parallel (%[[ARG4:.*]]) =
//  CHECK-SAME:       step (%[[C4]])
//       CHECK:       scf.for %[[ARG5:.*]] =
//  CHECK-SAME:         step %[[C8]]
//       CHECK:         %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG4]], %[[ARG5]]]
//       CHECK:         %[[SV2:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG5]]]
//       CHECK:         %[[SV3:.*]] = subview %{{.*}}[%[[ARG4]]]
//       CHECK:         linalg.generic
//  CHECK-SAME:           %[[SV1]], %[[SV2]], %[[SV3]]

// TILE1-LABEL: func @reduction
//   TILE1-DAG:   %[[C2:.*]] = constant 2 : index
//       TILE1:   scf.for %[[ARG3:.*]] =
//  TILE1-SAME:     step %[[C2]]
//       TILE1:         %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], 0, 0]
//       TILE1:         %[[SV2:.*]] = subview %{{.*}}[%[[ARG3]], 0]
//   TILE1-NOT:         subview
//       TILE1:         linalg.generic
//  TILE1-SAME:           %[[SV1]], %[[SV2]], %{{.*}}

// TILE2-LABEL: func @reduction
//   TILE2-DAG:   %[[C2:.*]] = constant 2 : index
//   TILE2-DAG:   %[[C4:.*]] = constant 4 : index
//       TILE2:   scf.for %[[ARG3:.*]] =
//  TILE2-SAME:     step %[[C2]]
//       TILE2:     scf.parallel (%[[ARG4:.*]]) =
//  TILE2-SAME:       step (%[[C4]])
//       TILE2:         %[[SV1:.*]] = subview %{{.*}}[%[[ARG3]], %[[ARG4]], 0]
//       TILE2:         %[[SV2:.*]] = subview %{{.*}}[%[[ARG3]], 0]
//       TILE2:         %[[SV3:.*]] = subview %{{.*}}[%[[ARG4]]]
//       TILE2:         linalg.generic
//  TILE2-SAME:           %[[SV1]], %[[SV2]], %[[SV3]]
