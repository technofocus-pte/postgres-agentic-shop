import React, { useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import ProductDetailPage from 'pages/products-view/product-detail/product-detail';
import ProductsListing from 'pages/products-view/product-listing/products-listing';
import { getUserIdFromSession } from 'utils/common-functions';

const ViewProductsRoute = () => {
  const { productId } = useParams();
  const navigate = useNavigate();
  const userId = getUserIdFromSession();

  useEffect(() => {
    if (!userId) {
      navigate('/users');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);
  if (!userId) return null; // Prevent render

  return productId ? <ProductDetailPage key={productId} /> : <ProductsListing key={productId} />;
};
export default ViewProductsRoute;
